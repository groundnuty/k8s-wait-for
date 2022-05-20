#!/bin/bash

PLATFORM=""

if [ -z "${TRAVIS_CPU_ARCH}" ]
then
    case $(uname -m) in
        i386)   PLATFORM="386" ;;
        i686)   PLATFORM="386" ;;
        x86_64) PLATFORM="amd64" ;;
        arm64)  PLATFORM="arm64" ;;
        arm)    dpkg --print-architecture | grep -q "arm64" && PLATFORM="arm64" || PLATFORM="arm" ;;
    esac
else
    PLATFORM="${TRAVIS_CPU_ARCH}"
fi

if [ -z $PLATFORM ]; then 
    echo "Platform could not be detected, aborting...";
    exit 1
fi

echo "linux/$PLATFORM"
