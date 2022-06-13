FROM docker.ops.iszn.cz/upstream/python:3.9-slim as build

# RUN apt-get update && \
#     apt-get install --yes \
#     libcurl4-openssl-dev \
#     libssl-dev \
#     gnupg2 \
#     curl

# RUN \
#     echo "deb http://repo/repo/buster-stable buster-stable main" \
#         > /etc/apt/sources.list.d/mapy-repo.list && \
#     curl -kL https://repo-web.dev.dszn.cz/gpg.asc | apt-key add - && \
#     apt-get update && \
#     apt-get install --yes \
#         gcc \
#         python3-venv \
#         libssl-dev \
#         goenvtemplator2

# WORKDIR /workspace


# ###############################################################################
# # Build python server
# FROM build AS build-python

ADD setup.py requirements.txt ./

# RUN \
#     python3 -m venv /app/env && \
#     /app/env/bin/pip install -U pip wheel && \
#     /app/env/bin/pip install -r requirements.txt && \
#     mkdir -p /app/conf/vassals

# ADD server ./server
# # RUN python setup.py pytest
# RUN /app/env/bin/pip install .


# ###############################################################################
# # Prepare "clean" dist image
# FROM docker.ops.iszn.cz/upstream/python:3.9-slim

# COPY --from=build-python /app /app
# COPY --from=build /usr/bin/goenvtemplator2 /usr/bin/
# ADD conf/*.tmpl /app/conf/
# ADD openapi.yaml /app/conf/

# RUN \
#     apt-get update && \
#     apt-get install --yes --no-install-recommends \
#         goenvtemplator2 && \
#     rm -rf /var/cache/apt /var/lib/apt
 
EXPOSE 8010

ENTRYPOINT [ \
    "goenvtemplator2", \
    "-template", "/app/conf/emperor.ini.tmpl:/app/conf/emperor.ini", \
    "-template", "/app/conf/private.ini.tmpl:/app/conf/vassals/private.ini", \
    "-exec", "/app/env/bin/uwsgi", "--ini", "/app/conf/emperor.ini" \
]


ARG VERSION
ARG BUILD_DATE
ARG BUILD_HOSTNAME
ARG BUILD_JOB_NAME
ARG BUILD_NUMBER
ARG BUILD_TYPE
ARG VCS_REF

LABEL org.label-schema.schema-version="1.0.0-rc.1" \
      org.label-schema.vendor="Seznam, a.s." \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.build-type="$BUILD_TYPE" \
      org.label-schema.build-ci-job-name="$BUILD_JOB_NAME" \
      org.label-schema.build-ci-build-id="$BUILD_NUMBER" \
      org.label-schema.build-ci-host-name="$BUILD_HOSTNAME" \
      org.label-schema.version="$VERSION" \
      org.label-schema.vcs-url="https://gitlab.seznam.net/tomas.sekanina/cicd-scout" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.name="cicd-scout" \
      org.label-schema.description="Gitlab CI/CD test project." \
      org.label-schema.usage="https://gitlab.seznam.net/tomas.sekanina/cicd-scout" \
      org.label-schema.url="https://gitlab.seznam.net/tomas.sekanina/cicd-scout"
