#!/usr/bin/env bash

# This script is used to help create runnable docker images of your application. it is the starting point for using intermediate build containers to create clean runnable images.

# set -x

# TODO: make these build methods more DRY

# ENVOY=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# DOCKERFILES=$ENVOY/.. # HACK

# utility function for failing with a messsage
function die() {
  echo "$@" 1>&2
  exit 1
}

# given the name of a project directory in Dockerfiles, build it
function build_image {
  PROJECT=$1
  echo Building image $PROJECT ...
  # if [ "$DRYRUN" == "false" ]; then
    $PROJECTS/$PROJECT/build-image.sh || exit 1
  # fi
}

# given an array of images and tags, build them
function build_images {
  IMAGES=${@}

  for FULL_IMAGE_NAME in $IMAGES; do

    IMAGE=${FULL_IMAGE_NAME#$IMAGE_PREFIX}

    PROJECT=$(echo $IMAGE | cut -d':' -f1)

    if [ -d "$PROJECTS/$PROJECT" ]; then

      echo Trying to build $IMAGE

      build_image $PROJECT

      docker inspect $FULL_IMAGE_NAME > /dev/null
      if [ $? -ne 0 ]; then
        echo "Error: Image $IMAGE does not exist. Perhaps you have the wrong branch of the project checked out."
        exit 1;

        # TODO: look at the git branch and error out there instead. tricky to do because the git repo name is stored in build-image.sh
      fi

    fi

  done;

}

# fetch the current branch name of the checked out git repo, and then sanitize it for acceptable characters for a docker tag
function get_git_branch {
  PROJECT_DIR=$1
  echo $(git --git-dir=$PROJECT_DIR/.git rev-parse --abbrev-ref HEAD|sed -e 's/[^a-zA-Z0-9_.\-]/_/g')
}

# returns the path to the local source directory of a project
function get_local_src_dir {
  PROJECT_DIR=$1

  # assumes the project is locally in the same directory as the Dockerfiles project
	PROJECT_LOCAL_REPO=$DOCKERFILES/../${PROJECT_DIR}/

  # perhaps they supplied an absolute path to an existing project directory
  # if [ -d ${PROJECT_DIR} ]; then
  if [[ ${PROJECT_DIR} == \/* ]]; then
    PROJECT_LOCAL_REPO=${PROJECT_DIR}/
  fi

  echo $PROJECT_LOCAL_REPO
}

# looks for a local source directory and checks it out from git if missing
function check_local_src {

	PROJECT_DIR=$1
  # REPO_BASE=${2:-git@github.com:PLOS}

  PROJECT_NAME=$(basename $PROJECT_DIR)
  PROJECT_LOCAL_REPO=$(get_local_src_dir $PROJECT_DIR)

  # checkout the project from git if it doesn't exist on the local machine
  if [ ! -d $PROJECT_LOCAL_REPO ];
    then
    echo "Source directory not found $PROJECT_LOCAL_REPO; fetching the project from github ..."
    git --version > /dev/null || die "git is not installed"

    git clone ${GIT_REMOTE_BASE}/${PROJECT_NAME} $PROJECT_LOCAL_REPO

    if [ ! -d $PROJECT_LOCAL_REPO ]; then die "git clone failed"; fi
  fi
}

# since the builder image builds the assets, we need a way to copy from the builder to the final resulting image. this method performs the pipe that sends the data from the builder to the runner
function _builder_to_runner() {

  BUILD_VOLUME=$1
  BUILD_IMAGE=$2
  RUN_IMAGE=$3

  docker run --rm --volume $BUILD_VOLUME:/build $BUILD_IMAGE sh -c 'tar -czf - -C /build .' | docker build -t $RUN_IMAGE - || die "build failed"
}

# This function is used to build docker images that use an intermediate builder image and uses a library cache
function build_image_compiled() {

  PROJECT_DIR=$1
  IMAGE_NAME=$2

  # this would include the prefix if the image is to be stored remotely
  FULL_IMAGE_NAME=${IMAGE_PREFIX}${2}

  # the builder image to use, for example maven or ruby
  BASE_IMAGE=$3
  SHARED_CACHE_NAME=$4
  SHARED_CACHE_PATH=$5

	# TODO: implement --no-cache option or mark images with build date

  PROJECT_NAME=$(basename $PROJECT_DIR)

  BASE_TAG=current

	BUILD_RESULT_DIR=${IMAGE_NAME}_build

  DOCKER_SETUP_DIR=$PROJECTS/$IMAGE_NAME

  PROJECT_LOCAL_REPO=$(get_local_src_dir $PROJECT_DIR)

	check_local_src $PROJECT_DIR

  # create shared library cache to use accross projects
  docker volume create --name $SHARED_CACHE_NAME

  # create build volume to store compiled assets
  docker volume create --name $BUILD_RESULT_DIR

  BASE_TAG=$(get_git_branch $PROJECT_LOCAL_REPO)

	echo "Compiling assets using base image ($BASE_IMAGE)..."

  # compile the assets using a container and save results to build volume
	docker run --rm \
    --volume $SHARED_CACHE_NAME:$SHARED_CACHE_PATH \
    --volume $BUILD_RESULT_DIR:/build \
    --volume $PROJECT_LOCAL_REPO:/src \
    --volume $DOCKER_SETUP_DIR:/scripts \
	  --volume $ENVOY:/envoy \
	  $BASE_IMAGE bash /scripts/compile.sh || die "compile failed"

	echo "Building runnable docker image ..."
  _builder_to_runner $BUILD_RESULT_DIR $BASE_IMAGE "$FULL_IMAGE_NAME:$BASE_TAG"

	# tag docker image with asset version number
	VERSION=$(docker run --rm --volume $BUILD_RESULT_DIR:/build $BASE_IMAGE cat /build/version.txt)

	echo "image tags = $FULL_IMAGE_NAME:$BASE_TAG and $FULL_IMAGE_NAME:$VERSION"

	docker tag $FULL_IMAGE_NAME:$BASE_TAG $FULL_IMAGE_NAME:$VERSION

  # clean up
  docker volume rm $BUILD_RESULT_DIR
}

# Build a docker image using maven
function build_image_maven() {

  PROJECT_DIR=$1
  IMAGE_NAME=$2

  # most of the depend on a base image so make sure it exists
  build_image tomcat

  build_image_compiled \
      $PROJECT_DIR $IMAGE_NAME \
      maven:3-jdk-8-alpine maven_local_repo /root/.m2
}

function build_rails_passenger_image() {


  # TODO: get this function working again


  PROJECT_DIR=$1
  IMAGE_NAME=${IMAGE_PREFIX}${2}

  PROJECT_NAME=$(basename $PROJECT_DIR)

  TMP_BUILD_CONTAINER=${IMAGE_NAME}_temp_container

  BASE_TAG=current

  # TODO: use $DOCKERFILES instead
  DOCKER_SETUP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$PROJECT_NAME

  # perhaps they supplied an absolute path to an existing project directory
  PROJECT_LOCAL_REPO=$DOCKER_SETUP_DIR/../../../${PROJECT_DIR}/

  if [[ ${PROJECT_DIR} == \/* ]]; then
    PROJECT_LOCAL_REPO=${PROJECT_DIR}/
  fi

  # TODO: git clone repo if it does not exist

  cd $DOCKER_SETUP_DIR

  cp Dockerfile $PROJECT_LOCAL_REPO      # this is a hack to allow the Dockerfile to exist in this subfolder

  cd $PROJECT_LOCAL_REPO

  # BASE_TAG=$(git rev-parse --abbrev-ref HEAD|sed -e 's/[^a-zA-Z0-9_.]/_/g')
  BASE_TAG=$(get_git_branch $PROJECT_LOCAL_REPO)

  time docker build -t $IMAGE_NAME:$BASE_TAG .
  # cd $DOCKER_SETUP_DIR
  rm $PROJECT_LOCAL_REPO/Dockerfile

  VERSION=$(docker run --volume $DOCKER_SETUP_DIR:/scripts \
  						--volume $ENVOY:/envoy \
  						--name $TMP_BUILD_CONTAINER $IMAGE_NAME:$BASE_TAG sh -c \
  							'cp /envoy/run-helpers.sh /scripts/* /root/;
  					     cat /root/version.txt || echo missing')

  docker commit --change "CMD bash /root/run.sh" $TMP_BUILD_CONTAINER $IMAGE_NAME:$BASE_TAG

  # tag docker image with asset version number

  # if [ "$VERSION" != "missing" ]; then
    echo tagging container with version : $VERSION
    docker tag $IMAGE_NAME:$BASE_TAG $IMAGE_NAME:$VERSION
  # fi

  docker rm $TMP_BUILD_CONTAINER
}

function build_rails_ember_images() {

  # previously used to build Akita before I seperated the builder into its own container

  PROJECT_DIR=$1
  IMAGE_NAME=${IMAGE_PREFIX}${2}

  PROJECT_NAME=$(basename $PROJECT_DIR)

  TMP_BUILD_CONTAINER=${IMAGE_NAME}_temp_container

  BASE_TAG=current

  # TODO: use $DOCKERFILES instead
  DOCKER_SETUP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$IMAGE_NAME

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

  docker commit --change "CMD bash /root/run.sh" $TMP_BUILD_CONTAINER $IMAGE_NAME:$BASE_TAG

  # tag docker image with asset version number

  echo tagging container with version : $VERSION

  docker tag $IMAGE_NAME:$BASE_TAG $IMAGE_NAME:$VERSION

  docker rm $TMP_BUILD_CONTAINER
}

# basically copies the Dockerfile into the src dir and then builds it
function build_image_non_compiled() {

	PROJECT_DIR=$1
	IMAGE_NAME=${IMAGE_PREFIX}${2}

  DOCKER_SETUP_DIR=$PROJECTS/$IMAGE_NAME
  PROJECT_LOCAL_REPO=$(get_local_src_dir $PROJECT_DIR)

  check_local_src $PROJECT_DIR

  BASE_TAG=$(get_git_branch $PROJECT_LOCAL_REPO)

  cd $DOCKER_SETUP_DIR
  # this is a hack to allow the Dockerfile to exist in this subfolder
  cp Dockerfile $PROJECT_LOCAL_REPO/Dockerfile.tmp
  cp project.dockerignore $PROJECT_LOCAL_REPO/.dockerignore

  cd $PROJECT_LOCAL_REPO

	echo "Building image..."
  docker build -f Dockerfile.tmp -t $IMAGE_NAME:$BASE_TAG . || die "build failed"

  echo "image tag = $IMAGE_NAME:$BASE_TAG"

  # TODO: should we handle if there is a version file or if they need the run helper?

  # clean up
  rm $PROJECT_LOCAL_REPO/{Dockerfile.tmp,.dockerignore}
}


# execute as subshell if this script is not being sourced
# [[ "${BASH_SOURCE[0]}" == "${0}" ]] && "$@"
