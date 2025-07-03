FROM scratch
ADD 3.22.rootfs.tar.gz /

# set version labels
ARG build_date
ARG version
LABEL build_date="${build_date}"
LABEL version="${version}"
LABEL maintainer="Nightah"

# set version for s6 overlay
ARG OVERLAY_VERSION="3.2.1.0"
ARG OVERLAY_ARCH="x86_64"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)$ " \
HOME="/root" \
S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
TERM="xterm"

RUN \
  echo "**** install build packages ****" && \
    apk add --no-cache --virtual=build-dependencies \
      curl \
      tar \
      xz && \
  echo "**** install runtime packages ****" && \
    apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      shadow \
      tzdata && \
  echo "**** add s6 overlay ****" && \
    curl -sSfL -o /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" && \
    curl -sSfL -o /tmp/s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.xz" && \
    tar -C / -Jpxf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jpxf /tmp/s6-overlay.tar.xz && \
  echo "**** patch CVE-2019-5021 ****" && \
    sed -i -e 's/^root::/root:!:/' /etc/shadow && \
  echo "**** create abc user and make our folders ****" && \
    groupmod -g 1000 users && \
    useradd -u 911 -U -d /config -s /bin/false abc && \
    usermod -G users abc && \
    mkdir -p \
      /app \
      /config \
      /defaults && \
  echo "**** cleanup ****" && \
    apk del --purge \
      build-dependencies && \
    rm -rf \
      /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
