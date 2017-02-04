#!/usr/bin/env bash

# script contains a function for command line operation of controlling flatrack. it should not be called directly.

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
      echo "Use: $SCRIPT test TESTNAME [stack]"
      echo
      echo "If you dont specify a stack, it will default to be the same as testname."
      echo
      echo TESTS:
      echo "$(find $TESTS -name "*.sh" ! -name "test-helpers.sh" ! -name "run.sh" -exec basename -s .sh -a {} +)"
      exit 1
    fi

    TEST=$1
    STACK=$1

    if [[ -n $2 ]]; then
      STACK=$2
    fi

    COMPOSE_FILE=$CONFIGURATIONS/$STACK.yml

    COMPOSE="docker-compose -f $COMPOSE_FILE"

    # TEST_IMAGE=testrunner

    echo Running tests/$TEST.sh against $COMPOSE_FILE

    # build test runner images if they do not exist
    docker images testrunner | grep -q flatrack || \
      docker build . --file $FLATRACK/testrunner.dockerfile --tag testrunner:flatrack || exit 2

    # TODO: change 'custom' to something like 'plos' so we can have more then one of these on a system
    docker images testrunner | grep -q custom || \
      docker build $TESTS --tag testrunner:custom || exit 3


    # kill the lingering instances and state
    $COMPOSE kill
    $COMPOSE rm -f -v

    # start stack
    $COMPOSE up -d
    $COMPOSE logs --no-color > $TESTS/lasttest.log &

    # TODO: is there a way to run this in the foreground perhaps so we can ^C out of it? as of now, that does not work.
    # run_the test in the container
    # docker-compose -f $CONFIGURATIONS/common.yml run --rm $TEST_IMAGE sh -c "source /flatrack/test-helpers.sh && bash /tests/$TEST.sh"

    # TODO: pass in env of TESTHELPERS as /flatrack/test-helpers.sh

    docker-compose -f $CONFIGURATIONS/common.yml run --rm testrunner bash /dockerfiles/tests/$TEST.sh

    # TODO: get this working so we can move it out of common.yml
    # docker run --rm --network=configurations -v $DOCKERFILES:/dockerfiles:ro -v /var/run/docker.sock:/var/run/docker.sock -v $FLATRACK:/flatrack:ro testrunner bash /dockerfiles/tests/$TEST.sh

    EXIT_CODE=$?

    [ $EXIT_CODE -eq 0 ] && echo "ALL TESTS PASSED"

    echo EXIT CODE : $EXIT_CODE

    # stop stack
    $COMPOSE kill
    $COMPOSE rm -f -v

    # preserve the exit code of the container test
    exit $EXIT_CODE

  else
    echo $USAGE
  fi

}
