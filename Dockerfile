FROM alpine:3.20.3

MAINTAINER Michal Orzechowski <orzechowski.michal@gmail.com>

ARG VCS_REF
ARG BUILD_DATE
ARG TARGETARCH

# Metadata
LABEL org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/groundnuty/k8s-wait-for" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.docker.dockerfile="/Dockerfile"

ENV KUBE_LATEST_VERSION="v1.31.1"

RUN apk add --update --no-cache ca-certificates=20220614-r0 curl=8.10.1 jq=1.6-r1 \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/$TARGETARCH/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Replace for non-root version
ADD wait_for.sh /usr/local/bin/wait_for.sh

ENTRYPOINT ["wait_for.sh"]
