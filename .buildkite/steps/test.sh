#!/usr/bin/env bash
set -u

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../libs/common.sh"

resolve_image
resolve_platform_image "${PLATFORM}" || exit 1

case "${PLATFORM}" in
  amd64) ALPINE_ARCH="x86_64"; ELF_MACHINE="62" ;;
  arm64) ALPINE_ARCH="aarch64"; ELF_MACHINE="183" ;;
  armv7) ALPINE_ARCH="armv7"; ELF_MACHINE="40" ;;
esac

REVISION="${BUILDKITE_COMMIT}"
OVERLAY_VERSION=$(sed -n 's/^ARG OVERLAY_VERSION="\(.*\)"$/\1/p' "${DOCKERFILE}")
MARKER="__TEST_OUTPUT__"
FAILURES=0

# Runs a shell script inside the container through /init and with-contenv, the same way the
# image's services run, and returns only the script's output (not the s6 startup banner).
run() {
  local options="$1" script="$2"
  # shellcheck disable=SC2086 # options holds multiple docker run flags and must be word split.
  docker run --rm --platform "${DOCKER_PLATFORM}" ${options} "${PLATFORM_IMAGE}" /command/with-contenv sh -c "echo ${MARKER}; ${script}" 2> /dev/null | sed "1,/^${MARKER}\$/d"
}

check() {
  local description="$1" expected="$2" actual="$3"

  if [[ "${actual}" == "${expected}" ]]; then
    echo "ok - ${description}"
  else
    echo "not ok - ${description}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual}"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- :label: Image metadata [${DOCKER_PLATFORM}]"
check "image platform is ${DOCKER_PLATFORM}" "${DOCKER_PLATFORM}" \
  "$(docker image inspect -f '{{.Os}}/{{.Architecture}}{{with .Variant}}/{{.}}{{end}}' "${PLATFORM_IMAGE}" | sed 's|^linux/arm64/v8$|linux/arm64|')"
check "entrypoint is /init" '["/init"]' "$(docker image inspect -f '{{json .Config.Entrypoint}}' "${PLATFORM_IMAGE}")"
check "cmd inherited from alpine is reset" "0" "$(docker image inspect -f '{{len .Config.Cmd}}' "${PLATFORM_IMAGE}")"
check "version label is ${BUILD_TAG}" "${BUILD_TAG}" "$(docker image inspect -f '{{index .Config.Labels "version"}}' "${PLATFORM_IMAGE}")"
check "build_date label is set" "set" "$(docker image inspect -f '{{with index .Config.Labels "build_date"}}set{{end}}' "${PLATFORM_IMAGE}")"
check "OCI revision label is ${REVISION}" "${REVISION}" "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "${PLATFORM_IMAGE}")"
check "OCI source label is the GitHub repository" "https://github.com/${GITHUB_REPOSITORY}" \
  "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.source"}}' "${PLATFORM_IMAGE}")"
check "OCI version label is ${BUILD_TAG}" "${BUILD_TAG}" "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' "${PLATFORM_IMAGE}")"
check "OCI created label is an RFC 3339 timestamp" "valid" \
  "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.created"}}' "${PLATFORM_IMAGE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' && echo valid)"

echo "--- :alpine: Base system"
check "alpine release is ${ALPINE_RELEASE}" "${ALPINE_RELEASE}" "$(run "" "cat /etc/alpine-release")"
check "apk architecture is ${ALPINE_ARCH}" "${ALPINE_ARCH}" "$(run "" "apk --print-arch")"
check "busybox is built for ${ALPINE_ARCH}" "${ELF_MACHINE}" "$(run "" "od -An -tu2 -j18 -N2 /bin/busybox" | xargs)"
check "runtime packages are installed" "bash ca-certificates coreutils shadow tzdata" \
  "$(run "" "for p in bash ca-certificates coreutils shadow tzdata; do apk info -e \$p; done" | xargs)"
check "build dependencies are removed" "" \
  "$(run "" "for p in .build-dependencies curl xz; do apk info -e \$p; done" | xargs)"
check "root password is locked (CVE-2019-5021)" "locked" \
  "$(run "" "grep '^root:' /etc/shadow | cut -d: -f2 | grep -qE '^[!*]' && echo locked")"
check "TZ is honoured" "AEST" "$(run "-e TZ=Australia/Brisbane" "date +%Z")"

echo "--- :package: s6-overlay"
check "s6-overlay version is ${OVERLAY_VERSION}" "ok" "$(run "" "test -d /package/admin/s6-overlay-${OVERLAY_VERSION} && echo ok")"
check "s6-overlay is built for ${ALPINE_ARCH}" "${ELF_MACHINE}" "$(run "" "od -An -tu2 -j18 -N2 /package/admin/s6/command/s6-svscan" | xargs)"
check "container exits 0 when the command succeeds" "0" "$(docker run --rm --platform "${DOCKER_PLATFORM}" "${PLATFORM_IMAGE}" true > /dev/null 2>&1; echo $?)"
check "container exits non-zero when the command fails" "1" "$(docker run --rm --platform "${DOCKER_PLATFORM}" "${PLATFORM_IMAGE}" false > /dev/null 2>&1; echo $?)"
CONTAINER=$(docker run -d --platform "${DOCKER_PLATFORM}" "${PLATFORM_IMAGE}")
sleep 10
check "container keeps running without a command" "true" "$(docker inspect -f '{{.State.Running}}' "${CONTAINER}")"
docker rm -f "${CONTAINER}" > /dev/null

echo "--- :bust_in_silhouette: abc user"
check "abc passwd entry" "abc:911:911:/config:/bin/false" "$(run "" "getent passwd abc | cut -d: -f1,3,4,6,7")"
check "abc is in the users group" "yes" "$(run "" "id -nG abc | tr ' ' '\n' | grep -qx users && echo yes")"
check "users group has gid 1000" "1000" "$(run "" "getent group users | cut -d: -f3")"
check "app directories are owned by abc" "911:911 911:911 911:911" "$(run "" "stat -c '%u:%g' /app /config /defaults" | xargs)"
check "startup banner reports default uid/gid" "911 911" \
  "$(docker run --rm --platform "${DOCKER_PLATFORM}" "${PLATFORM_IMAGE}" true 2>&1 | awk '/^User uid:/ {u=$3} /^User gid:/ {g=$3} END {print u, g}')"

echo "--- :wrench: PUID/PGID overrides"
# shellcheck disable=SC2016 # expanded inside the container, not here.
check "abc uid/gid follow PUID/PGID" "1234:4321" "$(run "-e PUID=1234 -e PGID=4321" 'echo $(id -u abc):$(id -g abc)')"
check "app directories follow PUID/PGID" "1234:4321 1234:4321 1234:4321" \
  "$(run "-e PUID=1234 -e PGID=4321" "stat -c '%u:%g' /app /config /defaults" | xargs)"

if [[ ${FAILURES} -gt 0 ]]; then
  echo "^^^ +++"
  echo "${FAILURES} check(s) failed"
  exit 1
fi

echo "All checks passed"
