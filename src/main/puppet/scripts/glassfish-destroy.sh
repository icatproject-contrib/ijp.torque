#!/bin/sh

test -e /home/dmf/glassfish4/bin/asadmin || exit 0

asadmin="/home/dmf/glassfish4/bin/asadmin --user admin"

domain=domain1
$asadmin stop-domain $domain
$asadmin delete-domain $domain

exit 0
