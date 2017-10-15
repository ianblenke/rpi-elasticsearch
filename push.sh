#!/bin/bash -e
. .env
if [[ $TRAVIS_BRANCH == 'master' && $TRAVIS_PULL_REQUEST == 'false' ]]; then
  docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
  docker push ${REPO}:v$ES_VERSION
  docker push ${REPO}:latest
fi
