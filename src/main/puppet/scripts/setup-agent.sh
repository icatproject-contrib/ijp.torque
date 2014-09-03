#!/bin/sh
set -e

release=$(lsb_release -cs)
echo "Using ubuntu codenamed $release"
[ -d puppet/modules ] || ( echo "No puppet/modules directory"; exit 1 )
export http_proxy=http://wwwcache.rl.ac.uk:8080 

if [ $# -ne 1 ]; then
    echo "Must have one argument - the full name of the server"
    exit 1
fi

# Fix the /etc/hosts
cat > /etc/hosts <<EOF
127.0.0.1       localhost

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

fqdn=$1

echo "Do apt-get update."
apt-get -qq update
echo "Get the puppet repo"
wget http://apt.puppetlabs.com/puppetlabs-release-${release}.deb 
dpkg -i puppetlabs-release-${release}.deb
rm -f puppetlabs-release-${release}.deb

apt-get -qq update
apt-get install -y puppet ntp

cat > /etc/default/puppet <<EOF
START=yes
DAEMON_OPTS="--logdest=/var/log/puppet/agent.log"
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

service puppet start

