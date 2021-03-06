#!/usr/bin/env bash

# this script contains a function for command line operation of controlling envoy. it should not be called directly.

# set -x

function cmd {

  SCRIPT=$0   # TODO: set from calling script somehow so help text is easier to read

  USAGE="Use: $SCRIPT build|stack|test [OPTIONS]"

  if [ "$#" -eq 0 ]; then
    echo $USAGE
    echo "Execute one of the above commands to see more options"
    exit 1
  fi

  OPERATION=$1

  shift

  if [[ "$OPERATION" == "stack" || "$OPERATION" == "compose" ]]; then

    # This script is basically a wrapper around docker-compose with some additional sugar for this project to help determine which compose file to run

    USAGE="Use: $SCRIPT stack STACKNAME"
    if [ "$#" -eq 0 ]; then
      echo $USAGE
      echo Choose a stack:
      list_stacks
    else
      STACK=$1
      shift

      args="$@"

      if (( $# == 0 )); then
        args="up"
      fi

      CMD="docker-compose -f $CONFIGURATIONS/$STACK.yml $args"
      echo $CMD
      $CMD

    fi

  elif [[ "$OPERATION" == "build" ]]; then

    COMMAND=$1
    NAME=$2

    USAGE="Use: $SCRIPT build image|stack|all name"

    if [ "$#" -eq 0 ]; then
      echo $USAGE
    elif [[ "$COMMAND" == "image" ]]; then

      if [ -z $NAME ]; then
        echo Choose an image to build:
        list_projects
      else
        build_image $NAME
      fi

    elif [ "$COMMAND" == "stack" ]; then

      if [ -z $NAME ]; then
        echo Choose a stack to build:
        list_stacks
      else
        IMAGES=$(get_images_from_config $CONFIGURATIONS/$NAME.yml)

        echo Building images: $IMAGES

        build_images $IMAGES
      fi
    elif [ "$COMMAND" == "all" ]; then
      projects=$(list_projects)
      for project in $projects
      do
        build_image $project
      done;
    else
      echo $USAGE
    fi

  elif [[ "$OPERATION" == "test" ]]; then

    if [ "$#" -eq 0 ]; then
      echo "Use: $SCRIPT test TESTNAME"
      echo
      echo TESTS:
      echo "$(find $TESTS -name "*.py" -exec basename -s .py -a {} +)"
      exit 1
    fi

    TEST=$1

    echo Running tests/$TEST.py

    cd $ENVOY
    docker build . --file testrunner.dockerfile --tag testrunner:envoy || exit 2
    cd -

    cd $TESTS
    # TODO: change 'custom' to something like 'plos' so we can have more then one of these on a system
    docker build . --tag testrunner:custom || exit 3
    cd -

    docker run --rm --network=configurations_default \
      -e "DOCKERFILES=$DOCKERFILES" \
      -e "CONFIGURATIONS=/dockerfiles/configurations" \
      -v $DOCKERFILES:/dockerfiles:ro \
      -v /var/run/docker.sock:/var/run/docker.sock \
      testrunner:custom \
      pytest -p no:cacheprovider --capture=no /dockerfiles/tests/${TEST}.py -v

    # pass up the exit code to the caller
    exit $?

  else
    echo $USAGE
  fi

}
