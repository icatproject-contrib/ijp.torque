#!/bin/sh
# Run as cron job to keep the ingest process alive, e.g in crontab:
# * * * * * /home/dmf/ingestion/relauncher.sh
# NOTE: crontab path must include /usr/local/bin to pick up the ijp client
#
cd /home/dmf/ingestion
if [ -f pidfile ] && ps $(cat pidfile) >> /dev/null
then
  # echo "Ingest process is running"
  exit
else
  # echo "Ingest process not running, so relaunch"
  ./launcher
fi
