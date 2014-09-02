#!/bin/sh

apt-get install -y mysql-client mysql-server

mysql -u icat -picat < /dev/null 2> /dev/null
rc=$?
if [ $rc -eq 0 ]; then
    echo "Database user 'icat' already exists so no need to create him"
else
    echo "*** You will be prompted for the MySQL root password"
    mysql -u root -p <<EOF
create user 'icat'@'localhost' identified by 'icat';
grant all on icat.* to 'icat'@'localhost';
grant all on authn_db.* to 'icat'@'localhost';
grant all on ijp.* to 'icat'@'localhost';
EOF
fi

set -e

mysql -u icat -picat <<EOF
create database if not exists icat;
create database if not exists authn_db;
create database if not exists ijp;
EOF
