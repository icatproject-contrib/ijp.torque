#!/bin/sh
set -e

release=$(lsb_release -cs)
echo "Using ubuntu codenamed $release"
[ -d puppet/modules ] || ( echo "No puppet/modules directory"; exit 1 )

# Local proxy setting no longer needed; 
# but off-site installations may still need to set one here
# export http_proxy=http://wwwcache.rl.ac.uk:8080 

cp -r puppet/modules /etc/puppet

echo "Run puppet agent - it should only show errors with the Torque::Server"
puppet agent -t
echo "*** update.sh completed ***"
