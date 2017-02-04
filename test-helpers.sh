
source /envoy/run-helpers.sh

# HELPER METHODS

function run_container_once {
  # so we can run a container from inside another container! DOCKERCEPTION
  IMAGE=$1
  DOCKERFILES=/dockerfiles docker-compose -f /dockerfiles/configurations/common.yml run --rm $IMAGE
}

function wait_and_curl {
  BASEURL=$1
  ROUTE=$2
  TITLE="$3"
  # CREDS=$4

  wait_for_web_service $BASEURL "$TITLE"
  test_up ${BASEURL}${ROUTE} "$TITLE" $4
}

# PUBLIC ASSERTIONS

function test_true {
  CONDITION=$? # NOTE: this is the result of the last command run, not a param
  TITLE="$1"
  [ $CONDITION -eq 0 ] && _passed "$TITLE" || _failed "$TITLE"
}

function test_up {
  URL=$1
  TITLE="$2"
  CREDS=$3

  HTTP_CODE=$(curl -Lk $CREDS -w "%{http_code}\\n" -s -o /dev/null $URL)

  if [[ "$HTTP_CODE" == "200" ]]; then
    _passed "($TITLE up) $URL"
  else
    _failed "($TITLE up) $URL" "status code = $HTTP_CODE"
  fi
}

# PRIVATE METHODS

function _failed {
  TITLE="$1"
  INFO=$2

  echo $TITLE FAILED $INFO
  exit 1
}

function _passed {
  echo "$1" PASSED
}
