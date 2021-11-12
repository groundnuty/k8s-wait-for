#!/bin/bash
PLATFORM=""
case $(uname -m) in
    i386)   PLATFORM="386" ;;
    i686)   PLATFORM="386" ;;
    x86_64) PLATFORM="amd64" ;;
    arm64)  PLATFORM="arm64" ;;
    arm)    dpkg --print-architecture | grep -q "arm64" && PLATFORM="arm64" || PLATFORM="arm" ;;
esac
echo "$PLATFORM"