#!/usr/bin/env python

# Use local cat_utils
# from ijp import cat_utils
from cat_utils import terminate, Session, IjpOptionParser
from ijp_lsf import lsf_utils

import os
import sys
from suds import WebFault
import time
import logging
import datetime
import traceback

def getDsName(directory):
    eles = directory[1:].split("/")[3:]
    if eles[0] == "SingleMolecule1": instrument = "OctopusSM1"
    elif  eles[0] == "SingleMolecule2" : instrument = "OctopusSM2"
    elif  eles[0] == "SingleMolecule3": instrument = "OctopusSM3"
    elif  eles[0] == "SingleMolecule4": instrument = "OctopusSM4"
    else: terminate ("Unable to determine instrument type for: " + input, 1)
    return instrument + "_" + "_".join(eles)  

logging.basicConfig(level=logging.CRITICAL)

usage = "usage: %prog dataset_file_or_dir investigation_name options"
parser = IjpOptionParser(usage)

# This script has no extra options; but does expect separate arguments to define the input (file/folder) and the investigation name

(options, args) = parser.parse_args()

jobName = sys.argv[0]

if not options.sessionId:
    terminate(jobName + " must specify an ICAT session ID", 1)

if not options.icatUrl:
    terminate(jobName + " must specify an ICAT url", 1)

if not options.idsUrl:
    terminate(jobName + " must specify an IDS url", 1)

if len(args) != 2: terminate(jobName + " must have 2 arguments: input-file/folder and investigation-name", 1) 
input = args[0]
investigationName = args[1]

if input.endswith("/"): input = input[:-1]
if os.path.isdir(input):
    print "Will process files inside", input
elif os.path.isfile(input):
    print "Will process a single file", input
else:
    terminate("Input '" + input + "' not found", 1)
    
session = Session("LSF", options.icatUrl, options.idsUrl, options.sessionId)

# TODO Should calls to factory.create() be replaced by session.create() ?
factory = session.factory

invs = session.search("Investigation [name = '" + investigationName + "']")
if invs: 
    investigation = invs[0]
else:
    terminate("Investigation '" + investigationName + "' not found in ICAT", 1)
  
dataset_type_name = os.path.basename(input)

# See if it is a simple dependency dataset
if dataset_type_name in ["beads", "bias", "dark", "flatfield", "checkimage.hdf5"]:
    if dataset_type_name == "beads": dataset_type_name = "bead"
    elif dataset_type_name == "checkimage.hdf5": dataset_type_name = "check"
    dataset_name = getDsName(input)

    try:
        dataset = factory.create("dataset")
        dataset.investigation = investigation
        dataset.name = dataset_name
        dataset.type = session.getDatasetType(dataset_type_name)
        dataset.startDate = dataset.endDate = datetime.datetime.today()
        dataset.id = session.create(dataset)
        
        datafile_format = session.search("DatafileFormat [name = '" + "unknown" + "']")[0]
        
        if os.path.isdir(input): 
            for file in os.listdir(input):
                datafile_name = os.path.basename(file)
                session.writeDatafile(os.path.join(input, file), dataset, datafile_name,
                    datafile_format)
        else:
            datafile_name = os.path.basename(input)
            session.writeDatafile(input, dataset, datafile_name,
                    datafile_format)
            
        dataset.complete = True
        session.update(dataset)
        print "Stored output dataset", dataset.id
    except WebFault as e:
        icatException = e.fault.detail.IcatException
        if icatException.type == "OBJECT_ALREADY_EXISTS":
            terminate(icatException.message, 2)
        else:
            terminate(icatException.type + ": " + icatException.message, 1)

elif os.path.isdir(input):

    do = lsf_utils.dumpxml(input)
    dsps = do.parameters
    depnames = ["bias_dir", "dark_dir", "bead_dir", "flatfield_dir", "check_image"]

    # Prepare dataset object
    dataset = factory.create("dataset")
    dataset.investigation = investigation
    dataset.name = getDsName(input)
    dataset.type = session.getDatasetType("dataset")
    dataset.startDate = dataset.endDate = datetime.datetime.today()

    # Check dependencies have been ingested and add to dataset
    for name in depnames:
        dep = dsps.get(name)
        if dep:
            dsType = name.split("_")[0]
            dep_dataset_name = getDsName(dep)
            query = "Dataset.id [type.name = ':dsType' AND name = ':dsName'] <-> Investigation [id = :invId]"
            query = query.replace(":dsType", dsType).replace(":dsName", dep_dataset_name).replace(":invId", str(investigation.id))
            dsids = session.search(query)
            if not dsids: terminate("Dependency data set missing " + query, 1)
            parameter = factory.create("datasetParameter")
            parameter.type = session.getParameterType(dsType + "_dataset" , "N/A")
            parameter.numericValue = dsids[0]
            dataset.parameters.append(parameter)

    # Check that expected datafiles exist
    for fpath in do.files:
        if fpath == input: terminate("File path " + fpath + " must start with " + input, 1)
        if not fpath.startswith(input): terminate("File path " + fpath + " must start with " + input, 1)
        if not os.path.isfile(fpath): terminate("File path " + fpath + " requested but does not exist", 1)

    # Add the other datasetparameters which are not dependencies
    for dsp in dsps:
        if dsp not in depnames:
            value = dsps[dsp]
            parameter = factory.create("datasetParameter")
            parameter.type = session.getParameterType(dsp, "N/A")
            if parameter.type.valueType == "STRING": parameter.stringValue = value
            elif parameter.type.valueType == "NUMERIC": parameter.numericValue = value
            else: parameter.dataTimeValue = value
            dataset.parameters.append(parameter)

    # Create the dataset in ICAT - return code 2 if it already exists
    try:
        dataset.id = session.create(dataset)
    except WebFault as e:
        icatException = e.fault.detail.IcatException
        if icatException.type == "OBJECT_ALREADY_EXISTS":
            terminate(icatException.message, 2)
        else:
            terminate(icatException.type + ": " + icatException.message, 1)

    # Add in the files - both specified and any unknown ones. A failure here will try to delete the dataset.
    try:
        print "Add files ",
        for fpath, (format, dfparms) in do.files.iteritems():
            sys.stdout.write('.')
            sys.stdout.flush()
            datafile_name = fpath[len(input) + 1:]
            datafile_format = session.getDatafileFormat(format, "1.0")

            dfid = session.writeDatafile(fpath, dataset, datafile_name, datafile_format)
            datafile = session.get("Datafile", dfid)
            for p, value in dfparms.iteritems():
                parameter = factory.create("datafileParameter")
                parameter.type = session.getParameterType(p, None)
                datafile = factory.create("datafile")
                datafile.id = dfid
                parameter.datafile = datafile
                if parameter.type.valueType == "STRING": parameter.stringValue = value
                elif parameter.type.valueType == "NUMERIC": parameter.numericValue = value
                else: parameter.dataTimeValue = value 
                parameter.id = session.create(parameter)

       
        for root, dirs, files in os.walk(input):
            for afile in files:
                sys.stdout.write('.')
                sys.stdout.flush()
                fpath = os.path.join(root, afile)
                if fpath not in do.files:
                    # FIXME this should generate an error - but for now we will be tolerant
                    datafile_name = fpath[len(input) + 1:]
                    datafile_format = session.getDatafileFormat("unknown", "1.0")
                    dfid = session.writeDatafile(fpath, dataset, datafile_name, datafile_format)
 
        dataset.complete = True
        session.update(dataset)
        print "\nDataset complete"
                        
    except Exception as e:
        traceback.print_exc()
        session.deleteDataset(dataset)
        terminate(e, 1)

else:
    terminate("Not a beads, dark etc. and not a directory", 1)
    
application = session.getApplication("ingest", "1.0")
session.storeProvenance(application, ods=[dataset])
print "Successfully wrote dataset with id, name and type", dataset.id, dataset.name, dataset.type.name
