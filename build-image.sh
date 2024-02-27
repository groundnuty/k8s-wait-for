#!/usr/bin/env bash

docker buildx build \
  --platform linux/amd64 \
  --tag intellum/k8s-wait-for:latest \
  --push \
  .
