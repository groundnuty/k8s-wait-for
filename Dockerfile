FROM alpine

RUN apk add --update --no-cache \
    ca-certificates \
    curl \
    jq \
    kubectl \
    helm

ADD wait_for.sh /usr/local/bin/wait_for.sh

ENTRYPOINT ["wait_for.sh"]
