#!/usr/bin/env bash

# .buildkite/libs/common.sh
#
# Shared values and helpers for the pipeline generator, hooks and step scripts.
# Source with a BASH_SOURCE-relative path so it works regardless of CWD:
#   source "$(dirname "${BASH_SOURCE[0]}")/libs/common.sh"        # from .buildkite/
#   source "$(dirname "${BASH_SOURCE[0]}")/../libs/common.sh"     # from .buildkite/hooks/ and .buildkite/steps/
#
# The variables set here and by resolve_image() are read by the sourcing files, which shellcheck can't see when
# linting this file in isolation.
# shellcheck disable=SC2034

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GITHUB_REPOSITORY="antilax-3/docker-baseimage-alpine"
DOCKER_REPOSITORY="antilax3/alpine"
REGISTRY="docker.io"
# Platforms every image is built for, by the short name used in test step keys and labels.
PLATFORMS="amd64 arm64 armv7"

DOCKERFILE="${REPOSITORY_ROOT}/Dockerfile"
# The Alpine series, e.g. 3.22, from the Dockerfile's pinned base image, e.g. FROM alpine:3.22.5@sha256:...
ALPINE_VERSION=$(sed -nE 's/^FROM alpine:([0-9]+\.[0-9]+)\.[0-9]+@sha256:[0-9a-f]+$/\1/p' "${DOCKERFILE}")

# Test jobs keyed "test-<platform>" get their platform from the step key, so steps don't each need it in env.
if [[ "${BUILDKITE_STEP_KEY:-}" == test-* ]]; then
  PLATFORM="${BUILDKITE_STEP_KEY#test-}"
fi

# Prints the Docker platform for a short platform name, e.g. armv7 -> linux/arm/v7.
docker_platform() {
  case "${1}" in
    amd64) echo "linux/amd64" ;;
    arm64) echo "linux/arm64" ;;
    armv7) echo "linux/arm/v7" ;;
  esac
}

# Returns success for pushes to master, the only builds that publish the latest and version tags.
master() {
  [[ "${BUILDKITE_BRANCH}" == "master" ]] && [[ "${BUILDKITE_PULL_REQUEST}" == "false" ]]
}

# Makes a branch name safe to use in a Docker tag.
sanitize_tag() {
  echo "${1}" | sed -E 's/[^A-Za-z0-9_.-]+/-/g'
}

# Resolves the image details for the build. Sets as globals:
#   BUILD_TAG - the build-scoped tag, e.g. BK12-3.22, also used as the version label/build arg
#   IMAGE     - the fully qualified build-scoped image the test step pulls
#   TAGS      - the tags pushed for the build context, following authelia/baseimage:
#                 renovate/*   -> renovate-<version>
#                 local branch -> <branch>-<version>
#                 fork PRs     -> PR<number>-<version> (Buildkite prefixes fork branch names with owner:)
#                 master       -> latest and <version>
#               and always BK<build>-<version>
resolve_image() {
  local version="${ALPINE_VERSION}"

  BUILD_TAG="BK${BUILDKITE_BUILD_NUMBER}-${version}"
  IMAGE="${REGISTRY}/${DOCKER_REPOSITORY}:${BUILD_TAG}"
  TAGS=""

  if [[ "${BUILDKITE_BRANCH}" =~ ^renovate/ ]]; then
    TAGS="renovate-${version}"
  elif [[ "${BUILDKITE_BRANCH}" != "master" ]] && [[ ! "${BUILDKITE_BRANCH}" =~ .*:.* ]]; then
    TAGS="$(sanitize_tag "${BUILDKITE_BRANCH}")-${version}"
  elif [[ "${BUILDKITE_BRANCH}" =~ .*:.* ]]; then
    TAGS="PR${BUILDKITE_PULL_REQUEST}-${version}"
  elif master; then
    TAGS="latest ${version}"
  fi

  TAGS+=" ${BUILD_TAG}"
}

# Resolves IMAGE (see resolve_image) to the manifest for one platform. Sets as globals:
#   DOCKER_PLATFORM - the Docker platform, e.g. linux/arm/v7
#   PLATFORM_IMAGE  - IMAGE pinned to that platform's manifest digest; tests of different platforms can share a
#                     Docker daemon, and pulling the multi-platform tag for each would race over the local tag.
#
# $1 - the short platform name, e.g. armv7
resolve_platform_image() {
  local digest

  DOCKER_PLATFORM=$(docker_platform "${1}")
  digest=$(docker buildx imagetools inspect "${IMAGE}" --format '{{json .Manifest}}' | jq -r --arg platform "${DOCKER_PLATFORM}" \
    '.manifests[] | select((.platform.os + "/" + .platform.architecture + (if .platform.variant then "/" + .platform.variant else "" end)) == $platform) | .digest')
  PLATFORM_IMAGE="${IMAGE%:*}@${digest}"
}
