FROM alpine

MAINTAINER Jono <jfinger@plos.org>
LABEL vendor="Public Library of Science"

RUN apk update && apk add curl bash docker python py-pip && \
    pip install 'docker-compose==1.8.0'
