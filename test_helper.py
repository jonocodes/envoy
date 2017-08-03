import requests
import logging
import sys
import os
import pytest
import shlex
import subprocess
from retry import retry
from singledispatch import singledispatch
from subprocess import call

logging.basicConfig(stream=sys.stderr )
logging.getLogger("log").setLevel( logging.DEBUG )
log=logging.getLogger("log")

# ASSERTION HELPER METHODS

@singledispatch
def assert_status(req, status_code=200):
  log.error('input type unmatched')
  assert False  # since input type unmatched

@assert_status.register(str)
def _(url, status_code=200):
  req = requests.get(url)
  assert req.status_code == status_code, req.text
  return req

@assert_status.register(requests.Response)
def _(req, status_code=200):
  assert req.status_code == status_code, req.text
  return req

# FIXTURE HELPERS FOR USING COMPOSE

def docker_compose(compose_config, command):
  compose = 'docker-compose -f ' + os.environ['CONFIGURATIONS'] + '/' + compose_config + '.yml'
  log.debug("RUN: " + compose + ' ' + command)
  subprocess.check_output(shlex.split(compose + ' ' + command))

@retry(tries=30, delay=3)
def wait_for_web_service(url):
  log.debug("Trying to reach " + url + " ...")
  req = requests.get(url)
  if req.status_code != 200:
    raise Exception('status=' + str(req.status_code))
  return req

@pytest.fixture(scope="class")
def stack(request):

  compose_config = getattr(request.module, "compose_config", "unknown")
  wait_urls = getattr(request.module, "wait_urls", "http://unknown:123")

  log.debug('compose_config: ' + compose_config)

  docker_compose(compose_config, 'kill')
  docker_compose(compose_config, 'rm -f -v')
  docker_compose(compose_config, 'up -d')

  for url in wait_urls:
    wait_for_web_service(url)

  yield

  docker_compose(compose_config, 'kill')
  docker_compose(compose_config, 'rm -f -v')
