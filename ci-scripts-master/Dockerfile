FROM docker.ops.iszn.cz/baseimage/debian:buster

ARG GIT_LFS_PKG_URL=""
ARG MINIO_CLIENT_URL=""
ARG DIRT_SCRIPTS_ARCHIVE_URL=""
ARG DEB_PACKAGES=""
ARG PIP_PACKAGES=""
ARG TRACE=""

COPY lib/* /ci/
COPY conf/* /ci/conf/
COPY depends.txt /ci/conf/
COPY checksums/* /ci/checksums/
COPY template/* /ci/template/

RUN /ci/install-ci-scripts.sh && rm -rf /ci/checksums /ci/conf

ARG BUILD_DATE
ARG BUILD_HOSTNAME
ARG BUILD_JOB_NAME
ARG BUILD_NUMBER
ARG BUILD_TYPE=manual
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0.0-rc.1" \
      org.label-schema.vendor="Seznam, a.s." \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.build-type="$BUILD_TYPE" \
      org.label-schema.build-ci-job-name="$BUILD_JOB_NAME" \
      org.label-schema.build-ci-build-id="$BUILD_NUMBER" \
      org.label-schema.build-ci-host-name="$BUILD_HOSTNAME" \
      org.label-schema.version="$VERSION" \
      org.label-schema.vcs-url="git@gitlab.seznam.net:generic/ci-scripts.git" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.name="ci-scripts" \
      org.label-schema.description="Seznam generic CI scripts" \
      org.label-schema.usage="https://gitlab.seznam.net/generic/ci-scripts" \
      org.label-schema.url="https://gitlab.seznam.net/generic/ci-scripts" \
      org.label-schema.docker.cmd="docker run -it"
