import httplib
import urlparse
import requests
import zipfile
import StringIO
from suds.client import Client
import sys
import threading
import datetime
import os
from urllib import urlencode
import ids
import tempfile
from optparse import OptionParser

def terminate(msg, status):
    """
    Stop execution with the specified message and exit code
    """
    if status % 2 == 0:
        print msg
    else:
        print >> sys.stderr, msg
    sys.exit(status)

def _readServices(path):
    result = {}
    with open(path) as ss:
        for line in ss.readlines():
            line = line.strip()
            if line:
                i = line.index(" ")
                key = line[:i].strip()
                value = line[i + 1:].strip()
                result[key] = value
    return result
    
class Session():
    """
    A session for using a specific facility
    """
    
    def __init__(self, facility_name, icat_url, ids_url, sessionId):
         
        if (icat_url == None) or (ids_url == None):
            print "Looking for ICAT/IDS urls in glassfish.services..."
            services = _readServices("/usr/local/etc/glassfish.services")
        if icat_url == None:
            print "ICAT url not supplied - use value from glassfish.services"
            icat_url = services["icaturl"]
        if ids_url == None:
            print "IDS url not supplied - use value from glassfish.services"
            ids_url = services["idsurl"]

        self.sessionId = sessionId
        self.client = Client(urlparse.urljoin(icat_url, "/ICATService/ICAT?wsdl"))
        self.idsClient = ids.IdsClient(ids_url)
        self.service = self.client.service
        self.factory = self.client.factory
        
        self.username = self.service.getUserName(self.sessionId)

        self.datasetTypes = {}
        self.parameterTypes = {}
        self.datafileFormats = {}
        self.applications = {}

        facilities = self.search("Facility [name = '" + facility_name + "']")
        if len(facilities) != 1: raise Exception("Facility " + facility_name + " is not known")
        self.facility = facilities[0]

        print "Session created for user", self.username, "of", self.facility.name 
        
    def deleteDataset(self, dataset):
        """
        Delete all the files of the dataset and the dataset itself
        """
        self.idsClient.delete(self.sessionId, datasetIds=[dataset.id])
        self.service.delete(self.sessionId, dataset)
        
    def unzipDataset(self, datasetId, path):
        """
        Retrieve the dataset and unzip it
        """
        fDesc, fName = tempfile.mkstemp()
        f = os.fdopen(fDesc, "w")
        resp = self.idsClient.getData(self.sessionId, datasetIds=[datasetId])
        chunk = resp.read(2048)
        while chunk:
            f.write(chunk)
            chunk = resp.read(2048)
        f.close()
        with zipfile.ZipFile(fName) as z:
            z.extractall(path)
        os.remove(fName)
        
    def search(self, query):
        """
        Perform an ICAT search
        """
        return self.service.search(self.sessionId, query)
    
    def get(self, query, key):
        """
        Perform an ICAT get
        """
        return self.service.get(self.sessionId, query, key)

    def create(self, entity):
        """
        Perform an ICAT create
        """
        return self.service.create(self.sessionId, entity)
    
    def update(self, entity):
        """
        Perform an ICAT update
        """
        self.service.update(self.sessionId, entity)

    def getDatasetType(self, name):
        """Lookup a DatasetType - making use of a cache"""
        dsType = self.datasetTypes.get(name)
        if not dsType:
            dsTypes = self.search("DatasetType [name = '" + name + "'] <-> Facility [name = '" + self.facility.name + "']")
            if len(dsTypes) == 0: raise Exception("No DatasetType " + name + " for facility " + self.facility.name)
            dsType = dsTypes[0]
            self.datasetTypes[name] = dsType
        return dsType

    def getParameterType(self, name, units):
        """Look up a ParameterType - making use of a cache"""
        # For now we ignore the units
        pType = self.parameterTypes.get((name, units))
        if not pType:
            pTypes = self.search("ParameterType [name = '" + name + "' and units = '" + units + "'] <-> Facility [name = '" + self.facility.name + "']")
            if len(pTypes) == 0: raise Exception("No ParameterType " + name + " " + units + " for facility " + self.facility.name)
            pType = pTypes[0]
            self.parameterTypes[name, units] = pType
        return pType

    def getDatafileFormat(self, name, version):
        """Look up a DatafileFormat - making use of a cache"""
        fType = self.datafileFormats.get((name, version))
        if not fType:
            fTypes = self.search("DatafileFormat [name = '" + name + "' and version = '" + version + "'] <-> Facility [name = '" + self.facility.name + "']")
            if len(fTypes) == 0: raise Exception("No DatafileFormat " + name + " " + version + " for facility " + self.facility.name)
            fType = fTypes[0]
            self.datafileFormats[name, version] = fType
        return fType
    
    def getApplication(self, name, version):
        """
        Look up an application - making use of a cache
        """
        app = self.applications.get((name, version))
        if not app:
            apps = self.search("Application [name = '" + name + "' and version = '" + version + "'] <-> Facility [name = '" + self.facility.name + "']")
            if len(apps) == 0: raise Exception("No Application " + name + " " + version + " for facility " + self.facility.name)
            app = apps[0]
            self.applications[name, version] = app
        return app
    
    def writeDatafile(self, file, dataset, name, format, description=None, doi=None, datafileCreateTime=None,
             datafileModTime=None):
        """
        Create an IDS file and catalogue it in ICAT
        """
        with open(file, "r") as body:
            dfid = self.idsClient.put(self.sessionId, body, name, dataset.id, format.id, description, doi, datafileCreateTime,
             datafileModTime)       
        return dfid
            
    def storeProvenance(self, application, arguments = None, ids=[], idf=[], ods=[], odf=[], ijpUrl = None, ijpJobId = None):
        """
        record provenance information.
        If ijpUrl and ijpJobId are supplied, link the IJP job to the provenance.
        """ 
        job = self.factory.create("job")
        
        if ids or idf:
            dataCollection = self.factory.create("dataCollection")
            for ds in ids:
                dataCollectionDataset = self.factory.create("dataCollectionDataset")
                dataCollection.dataCollectionDatasets.append(dataCollectionDataset)
                dataCollectionDataset.dataset = ds
            for df in idf:
                dataCollectionDatafile = self.factory.create("dataCollectionDatafile")
                dataCollection.dataCollectionDatafiles.append(dataCollectionDatafile)
                dataCollectionDatafile.datafile = df
            dataCollection.id = self.service.create(self.sessionId, dataCollection)
            job.inputDataCollection = dataCollection
            
        if ods or odf:
            dataCollection = self.factory.create("dataCollection")
            for ds in ods:
                dataCollectionDataset = self.factory.create("dataCollectionDataset")
                dataCollection.dataCollectionDatasets.append(dataCollectionDataset)
                dataCollectionDataset.dataset = ds
            for df in odf:
                dataCollectionDatafile = self.factory.create("dataCollectionDatafile")
                dataCollection.dataCollectionDatafiles.append(dataCollectionDatafile)
                dataCollectionDatafile.datafile = df
            dataCollection.id = self.service.create(self.sessionId, dataCollection)
            job.outputDataCollection = dataCollection                           

        job.application = application
        job.arguments = arguments
        job.id = self.service.create(self.sessionId, job)
        # If we know the IJP url and jobId, tell the IJP
        if ijpUrl and ijpJobId:
            url = ijpUrl + '/ijp/rest/jm/job/provenance/' + ijpJobId
            payload = {'provenanceId': job.id, 'sessionId': self.sessionId}
            requests.post(url, data=payload, verify=False)

        return job.id
 
class Tee(threading.Thread):
    
    def __init__(self, inst, *out):
        threading.Thread.__init__(self)
        self.inst = inst
        self.out = out
        
    def run(self):
        while 1:
            line = self.inst.readline()
            if not line: break
            for out in self.out:
                out.write(line)

class IjpOptionParser(OptionParser):
    """
    OptionParser that predefines some standard IJP options:
      --sessionId  - the ICAT session ID
      --icatUrl     - URL for the ICAT service
      --idsUrl      - URL for the IDS service
      --ijpUrl      - URL for the IJP service
      --ijpJobId    - the job ID used in IJP
      --datasetIds  - comma-separated list of dataset IDs
      --datafileIds - comma-separated list of datafile IDs
    The IJP will pass these options to job scripts if the job type
    specifies that the job will expect them.  The option dest names
    match their names, e.g.:
    
      usage = "usage: %prog options"
      parser = IjpOptions(usage)
      (options,args) = parser.parse_args()
      if options.datasetIds:
          datasetIdsList = options.datasetIds.split(',')
          ...
    """
    def __init__(self,usage):
        OptionParser.__init__(self,usage)
        self.add_option("--sessionId", dest="sessionId",
                      help="ICAT session ID")
        self.add_option("--icatUrl", dest="icatUrl",
                      help="ICAT url")
        self.add_option("--idsUrl", dest="idsUrl",
                      help="IDS url")
        self.add_option("--ijpUrl", dest="ijpUrl",
                      help="IJP url")
        self.add_option("--ijpJobId", dest="ijpJobId",
                      help="the job ID used in ijp")
        self.add_option("--datasetIds", dest="datasetIds",
                     help="comma-separated dataset IDs")
        self.add_option("--datafileIds", dest="datafileIds",
                     help="comma-separated datafile IDs")

