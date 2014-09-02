#!/bin/sh
set -e

if [ $# -ne  1 ]; then
    echo "Must give a password"
    exit 1
fi

asadmin="/home/dmf/glassfish4/bin/asadmin --user admin"
domain=domain1
cat > passwordfile <<EOF
AS_ADMIN_PASSWORD=$1
EOF
chmod 700 passwordfile
$asadmin delete-domain $domain
$asadmin --passwordfile passwordfile create-domain $domain
cp /root/downloads/mysql-connector-java*.jar /home/dmf/glassfish4/glassfish/domains/$domain/lib
$asadmin start-domain $domain
$asadmin --passwordfile passwordfile enable-secure-admin
rm passwordfile
$asadmin stop-domain $domain
$asadmin start-domain $domain
echo
echo "*** You will be prompted for the admin user name - hit return"
echo "*** ... then for the glassfish admin password you entered earlier"
echo
$asadmin login
$asadmin set server.http-service.access-log.format="common"
$asadmin set server.http-service.access-logging-enabled=true
$asadmin set server.thread-pools.thread-pool.http-thread-pool.max-thread-pool-size=128
$asadmin delete-ssl --type http-listener http-listener-2
$asadmin delete-network-listener http-listener-2
$asadmin create-network-listener --listenerport 8181 --protocol http-listener-2 http-listener-2
$asadmin create-ssl --type http-listener --certname s1as --ssl3enabled=false --ssl3tlsciphers +SSL_RSA_WITH_RC4_128_MD5,+SSL_RSA_WITH_RC4_128_SHA http-listener-2
$asadmin set configs.config.server-config.cdi-service.enable-implicit-cdi=false

$asadmin stop-domain
chown -R dmf:dmf /home/dmf/glassfish4/
mkdir -p ~dmf/.gfclient
cp ~/.gfclient/pass ~dmf/.gfclient/pass
chown -R dmf:dmf ~dmf/.gfclient
su -c "$asadmin start-domain" dmf
