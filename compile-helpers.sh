#!/usr/bin/env bash

# this script is only to be run inside the build container and it used to help with compiling assets

# set -x

BUILDDIR="/build"

# TODO: run tests in build?

function die() {
  echo "$@" 1>&2
  exit 1
}

# sometimes we build an image assuming things like configuration files are in a certain state. this method allows us to halt execution if we think one of those files has changed. if this does get triggered, we need to verify that the new config still works and update its checksum so the build can continue.
function verify_unchanged {
  FILE=$1
  CHECKSUM=$2

  CURRENT_CHECKSUM=($(md5sum $FILE))

  if [ $CHECKSUM != $CURRENT_CHECKSUM ]; then
    echo "Critical file checksum mismatch"
    echo $FILE expected $CHECKSUM but is currently $CURRENT_CHECKSUM
    exit 1
  fi
}

# copies the source code into the build container so we can cleanly compile it
function compile_prepare {

  rm -rf $BUILDDIR/*

  echo Compiling

  cd /src
  mkdir /root/src

  # bring in the source code, excluded unneeded dirs
  cp -r `ls -A | grep -Ev ".git|.idea|target"` /root/src
  cd /root/src

  # bring in the supporting dockerfiles scripts needed for run time
  cp /scripts/* $BUILDDIR
  cp /envoy/run-helpers.sh $BUILDDIR

  pwd
  du -sh
  # ls -la
}

function maven_fetch_version {

  PROPERTIES_FILE=$1

  grep ^version= $PROPERTIES_FILE | head -1 | sed 's/^version=//' > $BUILDDIR/version.txt
}
