FROM alpine:3.21.0

ARG VCS_REF
ARG BUILD_DATE
ARG TARGETARCH

# Metadata
LABEL org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.ref.name="k8s-wait-for" \
      org.opencontainers.image.ref.title="k8s-wait-for" \
      org.opencontainers.image.description="Allow to wait for a k8s service, job or pods to enter a desired state" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="Michal Orzechowski <orzechowski.michal@gmail.com>" \
      org.opencontainers.image.source="https://github.com/groundnuty/k8s-wait-for"

ENV KUBE_LATEST_VERSION="v1.31.4"

RUN apk add --update --no-cache ca-certificates=20241121-r0 curl=8.11.1-r0 \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/$TARGETARCH/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Replace for non-root version
ADD wait_for.sh /usr/local/bin/wait_for.sh

ENTRYPOINT ["wait_for.sh"]
