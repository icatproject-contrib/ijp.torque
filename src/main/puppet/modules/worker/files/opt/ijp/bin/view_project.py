#!/usr/bin/env python

import sys
from optparse import OptionParser
import os
import shutil
import subprocess
import traceback

from ijp import cat_utils
from ijp.cat_utils import terminate
from ijp_lsf.constants import *
from ijp_lsf import lsf_utils

exc = None
try:

    jobName, args = sys.argv[0], sys.argv[1:]

    if len(args) < 2: terminate(jobName + " must have at least 2 arguments: sessionId and datasetId", 1)
    
    sessionId, datasetId = args[:2]
    rest = args[2:]

    datasetId = int(datasetId)

    session = cat_utils.Session("LSF", sessionId)

    os.mkdir("tmp")

    print "Downloading dataset with id", datasetId
    lsf_utils.getUpperBranches(session, datasetId, "tmp")

    with open("msmm_dataset_root_marker.nodelete", "w") as dummy:
        pass
    
    cfg_file = None
    for name in ["run", "dataset"]:
        qfile = os.path.join("tmp",name+".cfg")
        if os.path.exists(qfile):
            cfg_file = qfile
            break
    if not cfg_file: terminate("No dataset configuration file found", 1)

    cfg = {}
    with open(cfg_file, "r") as runcfg:
        for line in runcfg:
            line = line.partition(" ")
            cfg[line[0].strip()] = line[2].replace("\\", "/").strip()

    try:
        path = cfg["RunDir"].partition("/")[2]
    except Exception:
        terminate(cfg_file + " does not have a RunDir entry with the expected format", 1)

    shutil.move("tmp", path)

    path = os.path.join(os.getcwd(), path)
    
    cmd = [MSMM_VIEWER_PROJECT, path] + rest
    print "About to run", cmd
    proc = subprocess.call(cmd)

    print "All done - hit return"
    sys.stdin.readline()

except Exception as e:

    exc = e
    traceback.print_exc()
    print "An error has occured - press return to continue."
    sys.stdin.readline()

except SystemExit as e:

    exc = e
    print "A fatal error has occured - press return to continue."
    sys.stdin.readline()

if exc: raise exc
