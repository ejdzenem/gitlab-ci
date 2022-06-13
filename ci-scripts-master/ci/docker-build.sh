#!/bin/bash

self=$(readlink -f $0)
dir=$(dirname $self)

DEB_PACKAGES=$(cat $dir/../depends.txt)
docker build --build-arg=DEB_PACKAGES="$DEB_PACKAGES" "$@"
