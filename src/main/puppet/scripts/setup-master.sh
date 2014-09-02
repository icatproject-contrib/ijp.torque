#!/bin/sh
set -e

fqdn=$(hostname -f)

# Fix the /etc/hosts
cat > /etc/hosts <<EOF
127.0.0.1       localhost

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# Unpack to ~/config directory
tar zxf ~/downloads/puppet-config-*.tar.gz -C /root

# Get repos complete
echo "Do apt-get update and add the puppetlabs repo..."
apt-get -qq update
wget http://apt.puppetlabs.com/puppetlabs-release-precise.deb 
dpkg -i puppetlabs-release-precise.deb
rm -f puppetlabs-release-precise.deb
apt-get -qq update

# Install jdk
mkdir -p /usr/java
tar zxf ~/downloads/jdk-*.tar.gz -C /usr/java
path=/usr/java/jdk*
update-alternatives --install "/usr/bin/java" "java" $path/bin/java 2001
update-alternatives --install "/usr/bin/javac" "javac" $path/bin/javac 2001

# Postgresql for puppetdb
apt-get install -y postgresql
su - postgres -c psql <<EOF
create role puppet login password 'puppet';
create database puppet owner = puppet;
EOF

# Set up database
db.sh

# Install rest of debs
apt-get install -y ntp puppetmaster puppet puppetdb puppet-el vim-puppet puppetdb-terminus

cat > /etc/default/puppet <<EOF
START=yes
DAEMON_OPTS="--logdest=/var/log/puppet/agent.log"
EOF

service puppetmaster stop
cat > /etc/default/puppetmaster <<EOF
START=yes
DAEMON_OPTS="--logdest=/var/log/puppet/master.log"
PORT=8140
EOF

service puppetdb stop
cat > /etc/puppetdb/conf.d/database.ini <<EOF
[database]
classname = org.postgresql.Driver
subprotocol = postgresql
subname = //localhost:5432/puppet
username = puppet
password = puppet
gc-interval = 60
log-slow-statements = 10
EOF

cat > /etc/puppet/puppet.conf <<EOF
[main]
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
factpath=\$vardir/lib/facter
templatedir=$confdir/templates

[master]
storeconfigs = true
storeconfigs_backend = puppetdb

[agent]
server=${fqdn}
report=true
EOF

cat > /etc/puppet/puppetdb.conf <<EOF
[main]
server=${fqdn}
EOF

cat > /etc/puppet/routes.yaml <<EOF
---
master:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

rm -rf /etc/puppet/modules
deploy-puppet-modules.sh

SITE=/etc/puppet/manifests/site.pp
echo "node '${fqdn}' {" > $SITE
echo "  include base" >> $SITE
echo "  include server" >> $SITE
cd /etc/puppet/modules
for f in base_* server_*; do
    [ -d "$f" ] || break
    echo "  include $f" >> $SITE
done
echo "}" >> $SITE

echo "" >> $SITE
echo "node 'default' {" >> $SITE
echo "  include base" >> $SITE
echo "  include worker" >> $SITE
cd /etc/puppet/modules
for f in base_* worker_*; do
    [ -d "$f" ] || break
    echo "  include $f" >> $SITE
done
echo "}" >> $SITE

mkdir -p /etc/puppet/modules/usergen/manifests
cat > /etc/puppet/modules/usergen/manifests/init.pp <<EOF
class usergen {
}
EOF

fdir=/etc/puppet/modules/common_account/files/batch
rm -rf $fdir
mkdir -p $fdir
ssh-keygen  -q -f $fdir/id_rsa -N ""
cp $fdir/id_rsa.pub $fdir/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAt3dNnH0JlZ0aSQy6RfiL6MJHsBFrw8ulJl36z/Oyq1kR55h8b8ldDn/sFbKmDjIOQoeHHMPxQJparkL06gEDI8cXkD6Dm4ge2Veovd7cCUbu42EMDRrQvwZdhxRl9YYVzv93vxDIj/kZ5etOEOhAx3Z6zmtaTWC43OFWHNvvLQn8XYSJUK4j9vLigLYIr5Xp5MhwBCCB34khK55YsXkXtS+hHN0N60S+1+DsLY1UpZnmtB+h0tx74at3IVPfQrapi0rvg/OhMuabnuT7e78Dzm154EgMhtBQmPUBAx+e6mW2tAOvyvWD4P4A+t6PwH2lOonbAx4yX8YDNEubgxthyw== Steve Fisher 2011-09-28" >> $fdir/authorized_keys
chmod +r $fdir/id_rsa

puppet module install puppetlabs-firewall
puppet module install ripienaar/concat
puppet module install puppetlabs/apt

update-rc.d puppetdb defaults

service puppetdb start
service puppetmaster start

# After a short pause to allow services to start run agent to create users etc.
echo "Will now sleep for 30 seconds..."
sleep 30
set +e
echo "Run puppet agent - silently"
puppet agent -t > /dev/null 2>&1
set -e

if test ! -e  /etc/nagios3/htpasswd.users; then
    echo "*** You will be prompted for a web password for user nagiosadmin"
    htpasswd -c /etc/nagios3/htpasswd.users nagiosadmin
fi

# Set up glassfish
glassfish-destroy.sh
rm -rf /home/dmf/glassfish4
cd /home/dmf
unzip -q ~/downloads/glassfish*.zip
echo
echo -n "Enter value to use for glassfish admin password: "
stty -echo
read pw
stty echo
echo
glassfish-setup.sh $pw

set +e
puppet agent -t > /dev/null 2>&1
echo "Run puppet agent - it should only show errors with the Torque::Server"
puppet agent -t
service puppet start
echo "*** setup-master.sh completed ***"
