#!/bin/bash -e
. .env
docker build \
  --build-arg ELASTICSEARCH_VERSION=$ES_VERSION \
  --build-arg ELASTICSEARCH_TARBALL_SHA1=$ES_SHA1 \
  --build-arg XPACK_VERSION=$XP_VERSION \
  --build-arg XPACK_TARBALL_SHA1=$XP_SHA1 \
  -t ${REPO}:v$ES_VERSION \
  .
docker tag ${REPO}:v$ES_VERSION ${REPO}:latest
