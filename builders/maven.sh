#!/usr/bin/env bash

# Build a docker image using maven that will run in tomcat

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../build-helpers.sh

PROJECT_DIR=$1
IMAGE_NAME=$2

# most of the depend on a base image so make sure it exists
# build_image tomcat

build_image_compiled \
    $PROJECT_DIR $IMAGE_NAME \
    maven:3-jdk-8-alpine maven_local_repo /root/.m2
