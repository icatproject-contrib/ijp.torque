#!/usr/bin/env python

import sys
import os
import shutil
import subprocess
import time
import logging
import datetime

from ijp import cat_utils
from ijp.cat_utils import terminate, factory
from ijp_lsf.constants import *
from ijp_lsf import lsf_utils

logging.basicConfig(level=logging.CRITICAL)

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
    qfile = os.path.join("tmp", name + ".cfg")
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
runcfg = os.path.join(path, name + ".cfg")

for deptype in ["Bead", "Bias", "Dark", "Flatfield", "Check"]:
    dep = session.search("DatasetParameter.numericValue <-> ParameterType[name = '" + deptype.lower() + "_dataset'] <-> Dataset [id = " + str(datasetId) + "]")
    if len(dep) > 1: terminate("More than one " + deptype + " dataset found for dataset id " + str(datasetId), 1)
    if dep:
        dep = int(dep[0])
        try:
            path = os.path.dirname(cfg[deptype + "Image"].partition("/")[2])
        except Exception:
            terminate("run.cfg does not have a " + deptype + "Image entry with the expected format", 1)
        if not os.path.exists(path): os.makedirs(path)
        print "Downloading", deptype, "dataset with id", dep
        lsf_utils.getUpperBranches(session, dep, path)

os.mkdir("MSMM_projects")
os.environ["MSMM_PROJECTS"] = os.path.join(os.environ["PWD"], "MSMM_projects")
cmd = [QUINCY, runcfg] + rest
print "Starting quincy", cmd

proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
with open("stdout", "w") as stdout, open("stderr", "w") as stderr:
    mstdout = cat_utils.Tee(proc.stdout, sys.stdout, stdout)
    mstdout.start()
    mstderr = cat_utils.Tee(proc.stderr, sys.stderr, stderr)
    mstderr.start()
    rc = proc.wait()   
    mstdout.join()
    mstderr.join()

project_name = None
project_id = None
project_dir = None

with open("stdout", "r") as stdout:
    for line in stdout:
        if line.startswith("* ProjectName="): project_name = line.partition("=")[2].strip()[1:-1]
        elif line.startswith("* ProjectId="): project_id = line.partition("=")[2].strip()[1:-1]
        elif line.startswith("* ProjectDir="): project_dir = line.partition("=")[2].strip()[1:-1]
        
if not (project_name and project_id and project_dir): terminate("Unable to determine one or more of ProjectName, ProjectId or ProjectDir from the job output", 1) 
        
print "ProjectName =", project_name
print "ProjectId =", project_id
print "Process return code was", rc

if rc: terminate("Quincy failed", rc) 

# Save the resulting dataset in the same investigation as the input

os.rename("stdout", os.path.join(project_dir, "quincy.log"))
print "Log file moved to project directory"

input_dataset = session.get("Dataset INCLUDE Investigation", datasetId)
investigation = input_dataset.investigation

do = lsf_utils.dumpxml(project_dir)

# Prepare dataset object
dataset = factory.create("dataset")
dataset.investigation = investigation
dataset.name = project_name + "_" + project_id
dataset.type = session.getDatasetType("project")
dataset.startDate = dataset.endDate = datetime.datetime.today()

# Check that expected datafiles exist
for fpath in do.files:
    if fpath == project_dir: terminate("File path " + fpath + " must start with " + project_dir, 1)
    if not fpath.startswith(project_dir): terminate("File path " + fpath + " must start with " + project_dir, 1)
    if not os.path.isfile(fpath): terminate("File path " + fpath + " requested but does not exist", 1)

# Add the dataset parameters
for dsp, value in do.parameters.iteritems():
    parameter = factory.create("datasetParameter")
    parameter.type = session.getParameterType(dsp, "N/A")
    if parameter.type.valueType == "STRING": parameter.stringValue = value
    elif parameter.type.valueType == "NUMERIC": parameter.numericValue = value
    else: parameter.dataTimeValue = value
    dataset.parameters.append(parameter)

# Create the dataset in ICAT - return code 2 if it already exists
try:
    dataset.id = session.create(dataset)
    print "Dataset id:", dataset.id, "created with name", dataset.name
except WebFault as e:
    icatException = e.fault.detail.IcatException
    if icatException.type == "OBJECT_ALREADY_EXISTS":
        terminate(icatException.message, 2)
    else:
        terminate(icatException.type + ": " + icatException.message, 1)

# Add in the files - both specified and any unknown ones. A failure here will try to delete the dataset.
try:
    for fpath, (format, dfparms) in do.files.iteritems():
        datafile_name = fpath[len(project_dir) + 1:]
        datafile_format = session.getDatafileFormat(format, "1.0")

        dfid = session.writeDatafile(fpath, dataset, datafile_name, datafile_format)
        print "Written file", datafile_name
        datafile = session.get("Datafile", dfid)
        for p, value in dfparms.iteritems():
            parameter = factory.create("datafileParameter")
            parameter.type = session.getParameterType(p, "N/A")
            datafile = factory.create("datafile")
            datafile.id = dfid
            parameter.datafile = datafile
            if parameter.type.valueType == "STRING": parameter.stringValue = value
            elif parameter.type.valueType == "NUMERIC": parameter.numericValue = value
            else: parameter.dataTimeValue = value 
            parameter.id = session.create(parameter)

    for root, dirs, files in os.walk(project_dir):
        for afile in files:
            fpath = os.path.join(root, afile)
            if fpath not in do.files:
                datafile_name = fpath[len(project_dir) + 1:]
                if datafile_name == "quincy.log":
                    datafile_format = session.getDatafileFormat("log", "1.0")
                else:  
                    datafile_format = session.getDatafileFormat("unknown", "1.0")
                dfid = session.writeDatafile(fpath, dataset, datafile_name, datafile_format)

    dataset.complete = True
    session.update(dataset)
                    
except Exception as e:
    session.deleteDataset(dataset)
    terminate(e, 1)

application = session.getApplication("quincy", "1.0")
arguments = " ".join([runcfg] + rest)
session.storeProvenance(application, arguments=arguments, ids=[input_dataset], ods=[dataset])
print "Provenance information stored"
