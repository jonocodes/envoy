FROM alpine

RUN apk update && apk add curl bash docker python py-pip && \
    pip install 'docker-compose==1.10.0'

# TODO: possibly remove this file, since the end user might want to inherit from a different base image. or perhaps do multistage build so docker-compose is passed in?
