#!/usr/bin/env bash

set -x

# Build a docker image that runs using Ember and Rails




# docker run --volume $(pwd):/frontend nodesource/trusty:0.12.9 sh -c 'cd /frontend && bin/setup'

# get node-sass working in alpine first
# https://github.com/sass/node-sass/issues/1589

# docker run -it --volume $(pwd):/frontend mhart/alpine-node:0.12 sh
# apk --update add bash
# cd /frontend
# bin/setup
#
# npm install --global node-sass --no-progress
#
# npm install node-sass@2.1.1
#
#
# apk add --no-cache ca-certificates git musl-dev \
#     && apk add --no-cache --virtual build-deps gcc g++ make python \
#     && npm install -g bower gulp node-sass \
#     && apk del build-deps
#
#
#
#
# cusspvz/node:0.12.15-development




source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../build-helpers.sh

# function build_rails_ember_images() {

  PROJECT_DIR=$1
  IMAGE_NAME=$2

  FULL_IMAGE_NAME=${IMAGE_PREFIX}${2}

  PROJECT_NAME=$(basename $PROJECT_DIR)

  TMP_BUILD_CONTAINER=${IMAGE_NAME}_temp_container

  BASE_TAG=current

  # TODO: use $DOCKERFILES instead
  DOCKER_SETUP_DIR=$PROJECTS/$IMAGE_NAME

  PROJECT_LOCAL_REPO=$DOCKER_SETUP_DIR/../../../${PROJECT_DIR}/

  if [[ ${PROJECT_DIR} == \/* ]]; then
    PROJECT_LOCAL_REPO=${PROJECT_DIR}/
  fi

  # TODO: git clone repo if it does not exist

  cd $DOCKER_SETUP_DIR

  cp Dockerfile $PROJECT_LOCAL_REPO      # this is a hack to allow the Dockerfile to exist in this subfolder
  cp project.dockerignore $PROJECT_LOCAL_REPO/.dockerignore

  # TODO: this overrides to base project. too sloppy
  cp *.yml $PROJECT_LOCAL_REPO/config
  cp setup-*.sh $PROJECT_LOCAL_REPO/bin/ && chmod +x $PROJECT_LOCAL_REPO/bin/setup-*.sh

  # if you pass the "clean" argument, the build will ignore the frontend dependencies that are on your host machine, and pull them down fresh in the container
  # if [ "$2" == "clean" ]; then
  # 	echo -e "frontend/dist\nfrontend/node_modules\nfrontend/bower_components\n" >> $PROJECT_LOCAL_REPO/.dockerignore
  # fi

  # cat $PROJECT_LOCAL_REPO/.dockerignore

  cd $PROJECT_LOCAL_REPO

  # BASE_TAG=$(git rev-parse --abbrev-ref HEAD|sed -e 's/[^a-zA-Z0-9_.]/_/g')
  BASE_TAG=$(get_git_branch $PROJECT_LOCAL_REPO)

  time docker build -t $IMAGE_NAME:$BASE_TAG .
  # cd $DOCKER_SETUP_DIR
  rm $PROJECT_LOCAL_REPO/Dockerfile
  rm $PROJECT_LOCAL_REPO/.dockerignore

  VERSION=$(docker run --volume $DOCKER_SETUP_DIR:/scripts \
  						--volume $ENVOY:/envoy \
  						--name $TMP_BUILD_CONTAINER $IMAGE_NAME:$BASE_TAG sh -c \
  							'cp /envoy/run-helpers.sh /scripts/* /root/;
  					     cat /root/version.txt')

  docker commit --change "CMD bash /root/run.sh" $TMP_BUILD_CONTAINER $FULL_IMAGE_NAME:$BASE_TAG

  # tag docker image with asset version number

  echo tagging container with version : $VERSION

  docker tag $FULL_IMAGE_NAME:$BASE_TAG $FULL_IMAGE_NAME:$VERSION

  docker rm $TMP_BUILD_CONTAINER
# }
