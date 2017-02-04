
# if there is a source project that you are trying to build and it does not exist, it will attempt to be cloned. this variable is the base path to the repo where the projects live
export GIT_REMOTE_BASE=git@github.com:PLOS

# this is the path to the flatrack project. you can set it here, or export it before this script exeutes
# export FLATRACK=/path/to/flatrack

# default paths to directories in your dockerfiles directory
export PROJECTS=$DOCKERFILES/projects

export TESTS=$DOCKERFILES/tests

export CONFIGURATIONS=$DOCKERFILES/configurations

[[ -n $FLATRACK ]] || {
  echo "Error: FLATRACK environment variable not set.";
  echo "Please set set it to the path of the flatrack scripts directory.";
  exit 5;

  # TODO: or git checkout flatrack?
}

[[ -n $DOCKERFILES ]] || {
  echo "Error: DOCKERFILES environment variable not set.";
  exit 6;
}

# echo FLATRACK: $FLATRACK
# echo DOCKERFILES: $DOCKERFILES
# echo CONFIGURATIONS: $CONFIGURATIONS

source $FLATRACK/build-helpers.sh
source $FLATRACK/stack-helpers.sh
