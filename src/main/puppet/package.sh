#!/bin/sh

if [ ! -f package.sh ]; then
    echo "package.sh not found - change directory"
    exit 1
fi

if [ $(find puppet -newer puppet-puppet*.tar.gz -type f | wc -l) -ne 0 ]; then
    rm -f puppet-puppet*.tar.gz
    tar --owner=root --group=root --exclude=".svn" -zcf puppet-puppet-1.0.0.tar.gz puppet
fi

if [ $(find scripts -newer puppet-scripts*.tar.gz -type f | wc -l) -ne 0 ]; then
    rm -f puppet-scripts*.tar.gz
    tar --owner=root --group=root --exclude=".svn" -zcf puppet-scripts-1.0.0.tar.gz scripts
fi
