FROM fluent/fluent-bit:1.4 as fluent

FROM golang:1.12 as builder

RUN mkdir -p /opt/fluent
WORKDIR /opt/fluent

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq --fix-missing \
    && apt-get install -y --no-install-recommends golint && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY Makefile .
COPY cloudwatch ./cloudwatch
COPY go.mod .
COPY go.sum .
COPY fluent-bit-cloudwatch.go .

RUN make

FROM ubuntu:focal

RUN mkdir -p /opt/fluent
WORKDIR /opt/fluent

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq --fix-missing \
    && apt-get install -y --no-install-recommends openssl libsasl2-2 libpq5 \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN update-ca-certificates

COPY --from=builder /opt/fluent/bin/cloudwatch.so .
COPY --from=fluent /fluent-bit/bin/fluent-bit .

ENTRYPOINT [ "bash", "-c", "./fluent-bit -e ./cloudwatch.so -i cpu -o cloudwatch -p 'region=us-west-2' -p 'log_group_name=fluent-bit-cloudwatch' -p 'log_stream_name=testing' -p 'auto_create_group=true'" ]
