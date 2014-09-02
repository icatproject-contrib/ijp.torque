#!/bin/sh

set -e

qmgr -c "set server operators = dmf@$(hostname -f)"
qmgr -c "set server managers = dmf@$(hostname -f)"

qmgr -c "set server acl_hosts = $(hostname -f)"
qmgr -c 'set server scheduling = true'
qmgr -c 'set server keep_completed = 300'
qmgr -c 'set server mom_job_sync = true'
qmgr -c "set server mail_domain = never"
qmgr -c "set server auto_node_np = false"

qmgr -c 'create queue batch'
qmgr -c 'set queue batch queue_type = execution'
qmgr -c 'set queue batch started = true'
qmgr -c 'set queue batch enabled = true'
qmgr -c 'set queue batch resources_default.walltime = 23:59:59'
qmgr -c 'set queue batch resources_default.nodes = 1'

qmgr -c 'set server default_queue = batch'

# Set flag to prevent this running again needlessly
touch /var/spool/torque/qmgred
