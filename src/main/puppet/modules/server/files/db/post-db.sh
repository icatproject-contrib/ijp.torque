#!/bin/sh
set -e

result=$(mysql -u icat -picat icat <<EOF
select * from FACILITY;
EOF
)

if [ -z "$result" ]; then
    mysql -u icat -picat icat < icat.dump
fi


mysql -u icat -picat authn_db<<EOF
insert into PASSWD (USERNAME, ENCODEDPASSWORD) VALUES('ingest','ingest') ON DUPLICATE KEY UPDATE ENCODEDPASSWORD='ingest';
insert into PASSWD (USERNAME, ENCODEDPASSWORD) VALUES('anon','anon') ON DUPLICATE KEY UPDATE ENCODEDPASSWORD='anon';
insert into PASSWD (USERNAME, ENCODEDPASSWORD) VALUES('reader','reader') ON DUPLICATE KEY UPDATE ENCODEDPASSWORD='anon';
EOF
