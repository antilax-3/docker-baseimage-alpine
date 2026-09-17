# syntax=docker/dockerfile:1
FROM alpine:3.22.5@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce

# set version labels
ARG build_date
ARG version
LABEL build_date="${build_date}"
LABEL version="${version}"
LABEL maintainer="Nightah"

# set version for s6 overlay
# renovate: datasource=github-releases depName=just-containers/s6-overlay
ARG OVERLAY_VERSION="3.2.1.0"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)$ " \
HOME="/root" \
S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
TERM="xterm"

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

RUN <<'EOF'
set -euo pipefail

echo "**** install build packages ****"
apk add --no-cache --virtual=build-dependencies \
  curl \
  tar \
  xz

echo "**** install runtime packages ****"
apk add --no-cache \
  bash \
  ca-certificates \
  coreutils \
  shadow \
  tzdata

echo "**** add s6 overlay ****"
OVERLAY_ARCH=$(apk --print-arch | sed 's/^armv7$/arm/')
curl -sSfL -o /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"
curl -sSfL -o /tmp/s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.xz"
tar -C / -Jpxf /tmp/s6-overlay-noarch.tar.xz
tar -C / -Jpxf /tmp/s6-overlay.tar.xz

echo "**** patch CVE-2019-5021 ****"
sed -i -e 's/^root::/root:!:/' /etc/shadow

echo "**** create abc user and make our folders ****"
groupmod -g 1000 users
useradd -u 911 -U -d /config -s /bin/false abc
usermod -G users abc
mkdir -p \
  /app \
  /config \
  /defaults

echo "**** cleanup ****"
apk del --purge \
  build-dependencies
rm -rf \
  /tmp/*
EOF

# add local files
COPY --link root/ /

ENTRYPOINT ["/init"]
