#!/usr/bin/env python

import sys
from optparse import OptionParser
import os
import shutil
import subprocess
import traceback

# Use local cat_utils
# from ijp import cat_utils
import cat_utils
from cat_utils import terminate, Session, IjpOptionParser
from ijp_lsf.constants import *
from ijp_lsf import lsf_utils

# May move this function into cat_utils
# Construct 'inner' command line from parsed options, omitting IJP options
def build_inner_options(options):
  cmd = []
  for option in vars(options):
    # skip IJP options
    if option not in ['sessionId','icatUrl','idsUrl','datasetIds','datafileIds']:
      value = getattr(options, option)
      if value == True:
        cmd += ['--' + option]
      elif type(value) is list:
        for elem in value:
          cmd += ['--' + option + '=' + str(elem)]
      elif value:
        cmd += ['--' + option + '=' + str(value)]
  return cmd

exc = None
try:

    usage = "usage: %prog dataset_id options"
    parser = IjpOptionParser(usage)
    
    # Options specific to this script:

    parser.add_option('--beads',action="store_true", default=False)
    parser.add_option('--reg-beads',action="store_true", default=False)
    parser.add_option('--non-ref-reg-error',action="store_true", default=False)
    parser.add_option('--ref-reg-error',action="store_true", default=False)
    parser.add_option('--whitelights',action="store_true", default=False)
    parser.add_option('--reg-whitelights',action="store_true", default=False)
    parser.add_option('--evidencemaps',action="store_true", default=False)
    parser.add_option('--reg-residualframes',action="store_true", default=False)
    parser.add_option('--reg-modelframes',action="store_true", default=False)
    parser.add_option('--trackmethod',type="string")
    # --trackmethod value enumeration controlled from IJP job type
    parser.add_option('--use-sigsqimage',action="store_true", default=False)
    parser.add_option('--no-tracks',action="store_true", default=False)
    parser.add_option('--hdf5-features',action="store_true", default=False)
    parser.add_option('--imrange',type="string")
    parser.add_option('--image-pattern',type="string")
    parser.add_option('--Levels.no-clean',type="int")
    parser.add_option('--Levels.min-features',type="int")
    parser.add_option('--Levels.chauvenet-threshold',type="int")
    parser.add_option('--EMCCD.em-gain',type="float")
    parser.add_option('--EMCCD.qe',type="float")
    parser.add_option('--EMCCD.electrons_adu',type="float")
    parser.add_option('--EMCCD.id',type="string")
    parser.add_option('--quit-on-idle',action="store_true", default=False)
    parser.add_option('--tag',type="string")

    (options, args) = parser.parse_args()
    
    jobName = os.path.basename(sys.argv[0])
    
    if not options.sessionId:
        terminate(jobName + " must specify an ICAT session ID", 1)
    
    # Report icat/ids URLs if present
    
    if not options.icatUrl:
        terminate(jobName + " must specify an ICAT url", 1)
    
    if not options.idsUrl:
        terminate(jobName + " must specify an IDS url", 1)
    
    sessionId = options.sessionId
    
    if not options.datasetIds:
        terminate(jobName + " must supply a dataset ID", 1)

    # Check that it's only a single ID, not a list
    
    if len(options.datasetIds.split(',')) > 1:
        terminate(jobName + ': expects a single datasetId, not a list: ' + options.datasetIds)
    
    datasetId = int(options.datasetIds)
    
    session = Session("LSF", options.icatUrl, options.idsUrl, sessionId)

    rest = args

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
    
    cmd = [MSMM_VIEWER_PROJECT, path] + build_inner_options(options) + rest
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
