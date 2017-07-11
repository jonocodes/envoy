#!/usr/bin/env bash

# Build a docker image that runs using Ember and Rails

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../build-helpers.sh

PROJECT_DIR=$1
IMAGE_NAME=$2

# has yarn and bash
build_image_compiled \
    $PROJECT_DIR $IMAGE_NAME \
    node:6 dummy_repo /tmp/dummy

# build_image_compiled \
#     $PROJECT_DIR $IMAGE_NAME \
#     nodesource/trusty:6 dummy_repo /tmp/dummy

# build_image_compiled \
#     $PROJECT_DIR $IMAGE_NAME \
#     node:6-alpine dummy_repo /tmp/dummy

# build_image_compiled \
#     $PROJECT_DIR $IMAGE_NAME \
#     nodesource/trusty:0.12.9 dummy_repo /tmp/dummy
