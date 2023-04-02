FROM alpine:3.17.3

RUN  apk update && apk add bash git openssl curl jq
COPY git-tool.sh /
