#!/usr/bin/env python

import sys
import os
import shutil
import subprocess
import time
import logging
import datetime
import traceback

from ijp import cat_utils
from ijp.cat_utils import terminate, factory
from ijp_lsf.constants import *
from ijp_lsf import lsf_utils

from lola.manager.Dataset import Dataset
from lola.manager import MiscUtil

class SessionTools:
        def __init__(self, session):
                self._session=session

        def download_dataset_dir(self, datasetId):
                dataset_dir=os.path.abspath("icat_dir_%d" % datasetId)
                os.makedirs(dataset_dir)
                self._session.unzipDataset(datasetId, dataset_dir)
                print("Downloaded dataset %d as directory %s" % (datasetId, dataset_dir))
                return dataset_dir

        def download_dataset_file(self, datasetId):
                dataset_dir=os.path.abspath("icat_file_%d" % datasetId) # FIXME Get correct filename from ICAT
                os.makedirs(dataset_dir)
                self._session.unzipDataset(datasetId, dataset_dir)

                # FIXME - work out filename after the fact...
                root, dirs, files=os.walk(dataset_dir).next() # Just get top entry
                if len(dirs)>0: raise RuntimeError("download_dataset_file: dir contains dir")
                if len(files)>1: raise RuntimeError("download_dataset_file: dir contains multiple files")
                dataset_file=os.path.join(root, files[0])

                print("Downloaded dataset %d as file %s" % (datasetId, dataset_file))
                return dataset_file

        def get_dataset(self, datasetId):
                return self._session.get("Dataset", datasetId)

        def list_dataset_parameter_values_numeric(self, datasetId, parameter_name):
                return self._session.search("DatasetParameter.numericValue <-> ParameterType[name = '%s'] <-> Dataset [id = %d]"
                                            % (parameter_name, datasetId))

        def list_dataset_parameter_values(self, datasetId, parameter_name):
                return self._session.search("DatasetParameter.value <-> Dataset[id = %d] <-> ParameterType[name = '%s']"
                                            % (datasetId, parameter_name)) 

        def list_dataset_parameter_names(self, datasetId):
                return self._session.search("ParameterType.name <-> DatasetParameter <-> Dataset[id = %d]"
                                            % datasetId)

        def get_dataset_parameter(self, datasetId, parameter_name):
                pars=self.list_dataset_parameter_values_numeric(datasetId, parameter_name)
                if len(pars)==0:
                        raise RuntimeError("No %s parameter found for dataset id %d" % (parameter_name, datasetId))
                if len(pars)>1:
                        raise RuntimeError("Multiple %s parameters found for dataset id %d" % (parameter_name, datasetId))
                return pars[0]

        def get_dataset_file_stuff(self, datasetId):
                return self._session.get("Dataset INCLUDE DatasetType", datasetId)

def cfg_change_entry(cfgfile, key, val):
    nchanged=MiscUtil.cfg_replace_lines(cfgfile, [key], "%s %s" % (key, val))
    if nchanged==0:
        raise RuntimeError("No %s entries found in %s" % (key, cfgfile))
    if nchanged>1:
        raise RuntimeError("Multiple %s entries found in %s" % (key, cfgfile))

def cfg_set_entry(cfgfile, key, val):
    nchanged=MiscUtil.cfg_replace_lines(cfgfile, [key], "%s %s" % (key, val))

def cfg_remove_entries(cfgfile, key):
    nremoved=MiscUtil.cfg_remove_lines(cfgfile, [key])

def download_dataset_and_dependencies(session, datasetId):
        
        with open("msmm_dataset_root_marker.nodelete", "w") as dummy:
            pass

        st=SessionTools(session)
        dataset_path=st.download_dataset_dir(datasetId)

        dset=Dataset(dataset_path)
        dsetcfg=dset.get_config_path()
        cfg_remove_entries(dsetcfg, "RunDir")
        cfg_set_entry(dsetcfg, "ExperimentSetup", os.path.join(dataset_path, os.path.split(dset.get_channel_config_path())[1]))

        if dset.has_beads():
            cfg_change_entry(dsetcfg, "BeadDir", st.download_dataset_dir(int(st.get_dataset_parameter(datasetId, "bead_dataset"))))
        if dset.has_biases():
            cfg_change_entry(dsetcfg, "BiasDir", st.download_dataset_dir(int(st.get_dataset_parameter(datasetId, "bias_dataset"))))
        if dset.has_darks():
            cfg_change_entry(dsetcfg, "DarkDir", st.download_dataset_dir(int(st.get_dataset_parameter(datasetId, "dark_dataset"))))
        if dset.has_flatfields():
            cfg_change_entry(dsetcfg, "FlatFieldDir", st.download_dataset_dir(int(st.get_dataset_parameter(datasetId, "flatfield_dataset"))))
        if dset.has_checkimage():
            cfg_change_entry(dsetcfg, "CheckImage", st.download_dataset_file(int(st.get_dataset_parameter(datasetId, "check_dataset"))))

        return dsetcfg

def Run():

        logging.basicConfig(level=logging.CRITICAL)

        jobName, args = sys.argv[0], sys.argv[1:]

        if len(args) < 2: raise RuntimeError(jobName + " must have at least 2 arguments: sessionId and datasetId")
            
        sessionId, datasetId = args[:2]

        # Collect together rest of parameters, processing boojums as special case (splitting value)
        rest=[]
        for par in args[2:]:
            if par.split()[0]=="--boojum":
                rest.extend(par.split())
            else:
                rest.append(par)

        datasetId = int(datasetId)

        session = cat_utils.Session("LSF", sessionId)

        dsetcfg=download_dataset_and_dependencies(session, datasetId)

        os.mkdir("MSMM_projects")
        os.environ["MSMM_PROJECTS"] = os.path.join(os.environ["PWD"], "MSMM_projects")
        cmd = [QUINCY, dsetcfg] + rest

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
                
        if not (project_name and project_id and project_dir): raise RuntimeError("Unable to determine one or more of ProjectName, ProjectId or ProjectDir from the job output") 
                
        print("ProjectName =", project_name)
        print("ProjectId =", project_id)
        print("Process return code was", rc)

        if rc: raise RuntimeError("Quincy failed", rc) 

        # Save the resulting dataset in the same investigation as the input

        os.rename("stdout", os.path.join(project_dir, "quincy.log"))
        print("Log file moved to project directory")

        input_dataset = session.get("Dataset INCLUDE Investigation", datasetId)
        investigation = input_dataset.investigation

        do = lsf_utils.dumpxml(project_dir)

        # Prepare dataset object
        dataset = factory.create("dataset")
        dataset.investigation = investigation
        dataset.name = project_name + "_" + project_id
        dataset.type = session.getDatasetType("project")
        dataset.location = investigation.name + "/" + dataset.name
        dataset.startDate = dataset.endDate = datetime.datetime.today()

        # Check that expected datafiles exist
        for fpath in do.files:
            if fpath == project_dir: terminate("File path " + fpath + " must start with " + project_dir)
            if not fpath.startswith(project_dir): raise RuntimeError("File path " + fpath + " must start with " + project_dir)
            if not os.path.isfile(fpath): raise RuntimeError("File path " + fpath + " requested but does not exist")

        # Add the dataset parameters
        for dsp, value in do.parameters.iteritems():
            parameter = factory.create("datasetParameter")
            parameter.type = session.getParameterType(dsp, None)
            if parameter.type.valueType == "STRING": parameter.stringValue = value
            elif parameter.type.valueType == "NUMERIC": parameter.numericValue = value
            else: parameter.dataTimeValue = value
            dataset.parameters.append(parameter)

        # Create the dataset in ICAT - return code 2 if it already exists
        try:
            dataset.id = session.create(dataset)
            print("Dataset id:",  dataset.id, "created with name",  dataset.name)
        except WebFault as e:
            icatException = e.fault.detail.IcatException
            if icatException.type == "OBJECT_ALREADY_EXISTS":
                raise RuntimeError(icatException.message, 2)
            else:
                terminate(icatException.type + ": " + icatException.message)

        # Add in the files - both specified and any unknown ones. A failure here will try to delete the dataset.
        try:
            for fpath, (format, dfparms) in do.files.iteritems():
                datafile_name = fpath[len(project_dir) + 1:]
                datafile_format = session.getDatafileFormat(format, "1.0")

                dfid = session.writeDatafile(fpath, dataset.location + "/" + datafile_name, dataset, datafile_name, datafile_format)
                print("Written file", datafile_name)
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

            for root, dirs, files in os.walk(project_dir):
                for afile in files:
                    fpath = os.path.join(root, afile)
                    if fpath not in do.files:
                        datafile_name = fpath[len(project_dir) + 1:]
                        if datafile_name == "quincy.log":
                            datafile_format = session.getDatafileFormat("log", "1.0")
                        else:  
                            datafile_format = session.getDatafileFormat("unknown", "1.0")
                        dfid = session.writeDatafile(fpath, dataset.location + "/" + datafile_name, dataset, datafile_name, datafile_format)

            dataset.complete = True
            session.update(dataset)
                            
        except Exception as e:
            session.deleteDataset(dataset)
            raise RuntimeError(e)

        session.storeProvenance("quincy", "1.0", ids = [input_dataset], ods = [dataset])
        print("Provenance information stored")

if __name__ == "__main__":

        try:
                Run()
        except Exception, err:
                sys.stderr.write("-"*80+"\n")
                traceback.print_exc(file=sys.stderr)
                sys.stderr.write("-"*80+"\n\n")
                terminate(str(err), 1)
