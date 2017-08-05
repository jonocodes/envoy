FROM alpine

RUN apk update && apk add curl bash docker python3 && \
    pip3 install 'docker-compose==1.14.0' requests retry pytest singledispatch && \
    mkdir /envoy-test-helper

COPY test_helper.py /envoy-test-helper

ENV PYTHONPATH=/envoy-test-helper
