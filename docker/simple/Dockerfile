# Dockerfile
ARG BASE_IMAGE
ARG PG_MAJOR
FROM ${BASE_IMAGE}

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-cron \
    postgresql-${PG_MAJOR}-partman \
  ; \
  rm -rf /var/lib/apt/lists/*
