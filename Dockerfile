FROM alpine:3.20.1

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

# explicit update of libcrypto to avoid CVE-2024-5535 (until base alpine is updated)
RUN apk add --update --no-cache ca-certificates=20240226-r0 curl=8.8.0-r0 jq=1.7.1-r0 libcrypto3=3.3.1-r1\
    && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/$TARGETARCH/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Replace for non-root version
ADD wait_for.sh /usr/local/bin/wait_for.sh

ENTRYPOINT ["wait_for.sh"]
