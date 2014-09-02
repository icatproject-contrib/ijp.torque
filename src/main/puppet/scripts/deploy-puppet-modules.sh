#!/bin/sh
set -e

for f in  ~/downloads/*-puppet-*.tar.gz; do
    tar zxf $f -C /etc
done
