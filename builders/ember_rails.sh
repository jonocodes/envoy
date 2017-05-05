#!/usr/bin/env bash

# Build a docker image that runs using Ember and Rails

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../build-helpers.sh

PROJECT_DIR=$1
IMAGE_NAME=$2

build_image_compiled \
    $PROJECT_DIR $IMAGE_NAME \
    nodesource/trusty:0.12.9 dummy_repo /tmp/dummy






# docker run --volume $(pwd):/frontend nodesource/trusty:0.12.9 sh -c 'cd /frontend && bin/setup'
