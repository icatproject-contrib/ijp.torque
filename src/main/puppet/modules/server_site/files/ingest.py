#!/usr/bin/env python

import os
import threading
import subprocess
import sys
import time
import ConfigParser
import signal

def process(*cmd):
    proc = subprocess.Popen(list(cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    pstdout, pstderr = proc.communicate();
    return proc.returncode, pstdout.splitlines(), pstderr.splitlines()

def checkdirs(*directories):
    for directory in directories:
        if not os.path.isdir(directory):
            print >> sys.stderr, directory, "does not exist"
            sys.exit(1)
            
def refresh():
    rc, out, err = process("ijp", "login", *creds.split())
    if rc:
        for line in err:
            print >> sys.stderr, line
        sys.exit(1)
        
def now():
    return time.strftime('%Y-%m-%d %H:%M:%S')

def terminate(msg):
    print >> sys.stderr, now(), msg
    sys.exit(1)
    
def processC(section, trigger, jobName, status, failures, faillog):
    rc, outout, err = process("ijp", "output", jobName)
    if rc:
        print now(), "problem getting output", jobName
        for line in err:
            print now(), section, trigger, line
    else:
        rc, errout, err = process("ijp", "output", "-e", jobName)
        if rc:
            print now(), "problem getting error output", jobName
            for line in err:
                print now(), section, trigger, line
        else:
            del status[trigger]
            if errout:
                if trigger not in failures: 
                    failures[trigger] = time.time()
                else:
                    if time.time() - failures[trigger] > maxtime:
                        print now(), "Trigger", section, trigger, "not processed fast enough so move it to failures directory"
                        os.rename(os.path.join(inputdir, trigger), os.path.join(failuresdir, trigger))
                        del failures[trigger]
                        with open (faillog, "a") as log:
                            print >> log, now(), "Trigger", section, trigger
                            for line in errout:
                                if line.strip():           
                                    print >> log, now(), "    " + line
                for line in errout:
                    if line.strip():
                        print  now(), section, trigger, "stderr", line
            else:
                os.rename(os.path.join(inputdir, trigger), os.path.join(donedir, trigger))
                if trigger in failures: del failures[trigger]
                print  now(), "Trigger", section, trigger, "processed succesfully"
            process("ijp", "delete", jobName)
            
def processQ(section, trigger, jobName, status, failures):
    rc, outout, err = process("ijp", "cancel", jobName)
    if rc:
        print now(), "problem cancelling", jobName
        for line in err:
            print now(), section, trigger, line
    else:
        process("ijp", "delete", jobName)
        if rc:
            print now(), "problem deleting", jobName
            for line in err:
                print now(), section, trigger, line
    del status[trigger]
    print now(), "Remove queued job as termination requested", section, trigger

term = 0
def handler(signum, frame):
    global term
    term = 1
    print now(), "signal", signum, "received"
    
signal.signal(signal.SIGTERM, handler)

args = sys.argv[1:]
if len(args) != 1: 
    terminate("Must have exactly one argument - the configuration file")

config = ConfigParser.ConfigParser()
config.set("DEFAULT", "maxtime", "1800")
if not config.read(args[0]):
    terminate("Configuration file " + args[0] + " not read")
    
creds = config.get("DEFAULT", "authn")
rc, out, err = process("ijp", "login", *creds.split())
if rc:
    for line in err:
        print >> sys.stderr, line
    terminate ("Authentication problem")

section_status = {}
section_failures = {}

for section in config.sections():
    ingdir = config.get(section, "directory") 
    faillog = config.get(section, "failures.log")
    inputdir = os.path.join(ingdir, "input")
    donedir = os.path.join(ingdir, "done")
    failuresdir = os.path.join(ingdir, "failures")
    checkdirs(inputdir, donedir, failuresdir)
    section_status[section] = {}
    section_failures[section] = {}
    print now(), "section", section, "has directory", ingdir, "with", len(os.listdir(inputdir)), "input", len(os.listdir(donedir)), "done and", len(os.listdir(failuresdir)), "failures"  

while True:
    # Submit jobs if not already done
    for section in config.sections():
       
        ingdir = config.get(section, "directory") 
        faillog = config.get(section, "failures.log")
        maxtime = config.getint(section, "maxtime")
        status = section_status[section]
        failures = section_failures[section]
        inputdir = os.path.join(ingdir, "input")
        donedir = os.path.join(ingdir, "done")
        failuresdir = os.path.join(ingdir, "failures")
        triggers = os.listdir(inputdir)[:]
        for trigger in triggers:
            if not term and trigger not in status: 
                with open(os.path.join(inputdir, trigger)) as f:
                    try:
                        line = f.readlines()[0].strip()
                        [t,investigationName] = line.split()
                    except Exception as e:
                        terminate ("Bad trigger file '" + os.path.join(inputdir, trigger));
                
                if investigationName:
                    rc, out, err = process("ijp", "submit", "ingest", t, investigationName)
    
                    if rc:
                        for line in err:
                            print now(), section, trigger, line
                    else:
                        jobName = out[0]
                        print now(), jobName, "submitted for", section, trigger
                        status[trigger] = "SUBMITTED " + jobName
                else:
                    print now(), "Trigger", section, trigger, "moved to failures directory - could not determine investigation name"
                    os.rename(os.path.join(inputdir, trigger), os.path.join(failuresdir, trigger))
                    with open (faillog, "a") as log:
                        print >> log, now(), "Trigger", section, trigger, " - no investigation name found"
                    
        statuses = status.keys()[:]
        for trigger in statuses:
            if status[trigger].startswith("SUBMITTED"):
                jobName = status[trigger][10:]
                rc, out, err = process("ijp", "status", jobName)

                if rc: 
                    print now(), "problem getting status", jobName
                    for line in err:
                        print now(), section, trigger, line
                else:
                    for line in out:
                        if line.split()[-1] == "Completed":
                            processC(section, trigger, jobName, status, failures, faillog)
                        elif term and line.split()[-1] == "Queued":
                            processQ(section, trigger, jobName, status, failures)
                                
    if term:
        waiting = False
        for section in config.sections():
            if section_status[section]:
                print now(), "waiting for", len(section_status[section]), section, "jobs to complete"
                waiting = True
                break
        if not waiting:
            print now(), "Stopping on SIGTERM"
            sys.exit(0)
            
    sys.stdout.flush()
    time.sleep(30)
    refresh()
