#!/bin/sh

deploy-puppet-modules.sh
tar zxf ~/downloads/puppet-config-*.tar.gz -C /root
tar zxf  ~/downloads/puppet-scripts-*.tar.gz -C /root

rm -f /usr/local/bin/ijp

puppet agent -t
