#!/usr/bin/env bash

# this script is to be run inside the test container

# set -x

MYSQL_ROOT="mysql --default-character-set=utf8 -h ${MYSQL_HOSTNAME} -u root --password=${MYSQL_ROOT_PASSWORD}"

function die {
  echo "$@" 1>&2
  exit 1
}

# makes sure required environment variables are set
function require_envs {
  LIST=("$@")

  for env in "${LIST[@]}"; do
    [[ ${!env} ]] || die "Missing required environment variable: $env"
  done
}

function require_mysql_envs {
  require_envs MYSQL_ROOT_PASSWORD MYSQL_USER MYSQL_USER_PASSWORD MYSQL_HOSTNAME MYSQL_DATABASE
}


# TODO: depricate in favor of start_tomcat.sh, though solr might depend on it?
function start_tomcat {

  # hack to prevent port conflicts when using host networking mode

  [[ -n $TOMCAT_HTTP_PORT ]] && sed -i -e "s/8080/$TOMCAT_HTTP_PORT/g" $CATALINA_HOME/conf/server.xml

  [[ -n $TOMCAT_CONTROL_PORT ]] && sed -i -e "s/8005/$TOMCAT_CONTROL_PORT/g" $CATALINA_HOME/conf/server.xml

  # end hack. note this might break the HEALTHCHECK

	${CATALINA_HOME}/bin/catalina.sh run
}

function start_consul_agent {

  CONSULSERVER=consulserver

  MAX_TRIES=5
  TRY_COUNT=0

  until check_host_up $CONSULSERVER ; do

    sleep 1
    ((TRY_COUNT++))

    echo "Attempt to contact $CONSULSERVER failed ($TRY_COUNT/$MAX_TRIES)"
    if [ $TRY_COUNT -gt $MAX_TRIES ]; then
      echo "Giving up on $CONSULSERVER"
      # break
      return
    fi

  done

  wait_for_web_service consulserver:8500/v1/agent/self "consulserver"

  /root/consul agent -data-dir /tmp/consul -config-dir /etc/consul.d -join consulserver &
}

function wait_until_db_service_up {

  # TODO: implement timeout?

	$MYSQL_ROOT -e 'exit'
	MYSQL_NOT_CONNECTING=$?
	while [ $MYSQL_NOT_CONNECTING -ne 0 ] ; do
    sleep 1;
    $MYSQL_ROOT -e 'exit'
    MYSQL_NOT_CONNECTING=$?
    echo -e "\nDatabase (${MYSQL_HOSTNAME}) not ready ... waiting"
	done;

	echo -e "\nDatabase (${MYSQL_HOSTNAME}) ready!"

}

function wait_until_true {

  TEST_CMD=$1
  NAME=$2
  TEST_RETURN_CODE=1

  while [ $TEST_RETURN_CODE -ne 0 ] ; do
    sleep 1
    $TEST_CMD
    TEST_RETURN_CODE=$?
    echo "$NAME not ready ... waiting"
  done;

  echo "$NAME is up and ready"
}

function wait_for_web_service {

  URL=$1
  NAME=$2
  # TEST_CMD="curl -skI $URL -o /dev/null"
  TEST_RETURN_CODE=1
  TRY_COUNT=0
  MAX_TRIES=30

  while [ $TEST_RETURN_CODE -ne 0 ] ; do
    sleep 3
    # $TEST_CMD
    curl -skI $URL -o /dev/null
    TEST_RETURN_CODE=$?

    ((TRY_COUNT++))
    echo "Service $NAME ($URL) not ready ... waiting ($TRY_COUNT/$MAX_TRIES)"

    if [ $TRY_COUNT -gt $MAX_TRIES ]; then
      die "Service did not respond in a reasonable amount of time"
    fi

  done;

  echo "Service $NAME ($URL) is up and ready for tests"
}

function check_host_up {
  HOST=$1
  ping -c2 $HOST &> /dev/null # && echo "up" || echo "down"
}

function set_db_grants {

	echo -e "\nCreating DB User (${MYSQL_USER})"
	echo "CREATE USER '${MYSQL_USER}' IDENTIFIED BY '${MYSQL_USER_PASSWORD}'" | ${MYSQL_ROOT}
	echo "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES" | ${MYSQL_ROOT}
  # echo "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_USER_PASSWORD}'" | ${MYSQL_ROOT}
  # echo "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES" | ${MYSQL_ROOT}
	echo "Finished creating user."

}

function check_db_exists {

  DB=${1:-${MYSQL_DATABASE}}

	# this function exists because we dont want to recreate a DB if we are pointing to a service that already has a running schema on it
	$MYSQL_ROOT -e "use ${DB}"
}

function create_db {
  DB=${1:-${MYSQL_DATABASE}}
  # echo "CREATE DATABASE ${DB}"
  echo "CREATE DATABASE ${DB}" | ${MYSQL_ROOT}
}

function process_env_template {
	CONTEXT_TEMPALTE=$1

  ls -lh $CONTEXT_TEMPALTE

	echo "Processing template $CONTEXT_TEMPALTE"

  eval "cat <<EOF
$(<$CONTEXT_TEMPALTE)
EOF
" > $CONTEXT_TEMPALTE
}
