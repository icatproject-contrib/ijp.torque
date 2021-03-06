package org.icatproject.ijp.r92;

import java.io.BufferedWriter;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.io.StringReader;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.charset.Charset;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

import javax.annotation.PostConstruct;
import javax.ejb.EJB;
import javax.ejb.Schedule;
import javax.ejb.Stateless;
import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.Response.Status;
import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;
import javax.xml.bind.Unmarshaller;
import javax.xml.namespace.QName;

import org.icatproject.ICAT;
import org.icatproject.ICATService;
import org.icatproject.IcatExceptionType;
import org.icatproject.IcatException_Exception;
import org.icatproject.ijp.batch.BatchJson;
import org.icatproject.ijp.batch.JobStatus;
import org.icatproject.ijp.batch.OutputType;
import org.icatproject.ijp.batch.exceptions.ForbiddenException;
import org.icatproject.ijp.batch.exceptions.InternalException;
import org.icatproject.ijp.batch.exceptions.ParameterException;
import org.icatproject.ijp.batch.exceptions.SessionException;
import org.icatproject.utils.CheckedProperties;
import org.icatproject.utils.ShellCommand;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Session Bean implementation to manage job status
 */
@Stateless
public class JobManagementBean {

	private QName qName = new QName("http://icatproject.org", "ICATService");

	@EJB
	private MachineEJB machineEJB;

	private String defaultFamily;

	private Unmarshaller qstatUnmarshaller;

	private Map<String, List<String>> families = new HashMap<>();

	@PostConstruct
	void init() {

		try (PrintStream p = new PrintStream(Constants.USERGEN)) {
			CheckedProperties props = new CheckedProperties();
			props.loadFromFile(Constants.PROPERTIES_FILEPATH);

			String familiesList = props.getString("families.list");
			p.println("class usergen {");
			for (String mnemonic : familiesList.split("\\s+")) {
				if (defaultFamily == null) {
					defaultFamily = mnemonic;
				}
				String key = "families." + mnemonic + ".members";
				String[] members = props.getString(key).split("\\s+");
				families.put(mnemonic, new ArrayList<>(Arrays.asList(members)));
				logger.debug("Family " + mnemonic + " contains " + families.get(mnemonic));
				String format = props.getString("families." + mnemonic + ".puppet");
				for (String member : families.get(mnemonic)) {
					p.format(format, member);
					p.println();
				}
			}
			if (defaultFamily == null) {
				String msg = "No families defined";
				logger.error(msg);
				throw new IllegalStateException(msg);
			}

			p.println('}');

			qstatUnmarshaller = JAXBContext.newInstance(Qstat.class).createUnmarshaller();

			CheckedProperties portalProps = new CheckedProperties();
			portalProps.loadFromFile(Constants.PROPERTIES_FILEPATH);
			if (portalProps.has("javax.net.ssl.trustStore")) {
				System.setProperty("javax.net.ssl.trustStore", portalProps.getProperty("javax.net.ssl.trustStore"));
			}

			statusMapper.put("C", JobStatus.Completed);
			statusMapper.put("E", JobStatus.Executing);
			statusMapper.put("H", JobStatus.Held);
			statusMapper.put("Q", JobStatus.Queued);
			statusMapper.put("R", JobStatus.Executing);
			statusMapper.put("T", JobStatus.Queued);
			statusMapper.put("W", JobStatus.Queued);
			statusMapper.put("S", JobStatus.Held);

			logger.info("Set up R92 JobManagementBean with default family " + defaultFamily);
		} catch (Exception e) {
			String msg = e.getClass() + " reports " + e.getMessage();
			logger.error(msg);
			throw new IllegalStateException(msg);
		}

	}

	private final static Logger logger = LoggerFactory.getLogger(JobManagementBean.class);
	private final static Random random = new Random();

	@PersistenceContext(unitName = "r92")
	private EntityManager entityManager;

	private Map<String, JobStatus> statusMapper = new HashMap<>();

	public List<R92Job> getJobsForUser(String sessionId, String icatUrl) throws SessionException, ParameterException {
		String username = getUserName(sessionId, icatUrl);
		return entityManager.createNamedQuery(R92Job.FIND_BY_USERNAME, R92Job.class).setParameter("username", username)
				.getResultList();
	}

	public InputStream getJobOutput(String jobId, OutputType outputType, String sessionId, String icatUrl)
			throws SessionException, ForbiddenException, InternalException, ParameterException {
		logger.info("getJobOutput called with sessionId:" + sessionId + " jobId:" + jobId + " outputType:" + outputType);
		R92Job job = getJob(jobId, sessionId, icatUrl);
		String ext = "." + (outputType == OutputType.STANDARD_OUTPUT ? "o" : "e") + jobId.split("\\.")[0];
		Path path = FileSystems.getDefault().getPath("/home/batch/jobs", job.getBatchFilename() + ext);
		if (!Files.exists(path)) {
			logger.debug("Getting intermediate output for " + jobId);
			ShellCommand sc = new ShellCommand("sudo", "-u", "batch", "ssh", job.getWorkerNode(), "sudo",
					"push_output", job.getBatchUsername(), path.toFile().getName());
			if (sc.isError()) {
				throw new InternalException("Temporary? problem getting output " + sc.getStderr());
			}
			path = FileSystems.getDefault().getPath("/home/batch/jobs", job.getBatchFilename() + ext + "_tmp");
		}
		if (Files.exists(path)) {
			logger.debug("Returning output for " + jobId);
			try {
				return Files.newInputStream(path);
			} catch (IOException e) {
				throw new InternalException(e.getClass() + " reports " + e.getMessage());
			}
		} else {
			throw new InternalException("No output file available at the moment");
		}
	}

	@Schedule(minute = "*/1", hour = "*")
	private void updateJobsFromQstat() {
		try {

			ShellCommand sc = new ShellCommand("qstat", "-x");
			if (sc.isError()) {
				throw new InternalException("Unable to query jobs via qstat " + sc.getStderr());
			}
			String jobsXml = sc.getStdout().trim();
			if (jobsXml.isEmpty()) {
				/* See if any jobs have completed without being noticed */
				for (R92Job job : entityManager.createNamedQuery(R92Job.FIND_INCOMPLETE, R92Job.class).getResultList()) {
					logger.warn("Updating status of job '" + job.getId() + "' from '" + job.getStatus()
							+ "' to 'C' as not known to qstat");
					job.setStatus("C");
				}
				return;
			}

			Qstat qstat = (Qstat) qstatUnmarshaller.unmarshal(new StringReader(jobsXml));
			for (Qstat.Job xjob : qstat.getJobs()) {
				String id = xjob.getJobId();
				String status = xjob.getStatus();
				String wn = xjob.getWorkerNode();
				String workerNode = wn != null ? wn.split("/")[0] : "";

				R92Job job = entityManager.find(R92Job.class, id);
				if (job != null) {
					if (!job.getStatus().equals(xjob.getStatus())) {
						logger.debug("Updating status of job '" + id + "' from '" + job.getStatus() + "' to '" + status
								+ "'");
						job.setStatus(status);
					}
					if (!job.getWorkerNode().equals(workerNode)) {
						logger.debug("Updating worker node of job '" + id + "' from '" + job.getWorkerNode() + "' to '"
								+ workerNode + "'");
						job.setWorkerNode(workerNode);
					}

				}
			}
		} catch (Exception e) {
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			e.printStackTrace(new PrintStream(baos));
			logger.error("Update of db jobs from qstat failed. Class " + e.getClass() + " reports " + e.getMessage()
					+ baos.toString());
		}
	}

	public String submitBatch(String username, String executable, List<String> parameters, String family)
			throws ParameterException, InternalException, SessionException {

		if (family == null) {
			family = defaultFamily;
		}
		List<String> members = families.get(family);
		if (members == null) {
			throw new ParameterException("Specified family " + family + " is not recognised");
		}
		String owner = members.get(random.nextInt(members.size()));

		/*
		 * The batch script needs to be written to disk by the dmf user (running
		 * glassfish) before it can be submitted via the qsub command as a less
		 * privileged batch user. First generate a unique name for it.
		 */
		Path batchScriptFile = Paths.get(Constants.DMF_WORKING_DIR_NAME, UUID.randomUUID().toString());

		createScript(batchScriptFile, parameters, executable);

		ShellCommand sc = new ShellCommand("sudo", "-u", owner, "qsub", "-k", "eo", batchScriptFile.toAbsolutePath()
				.toString());
		if (sc.isError()) {
			throw new InternalException("Unable to submit job via qsub " + sc.getStderr());
		}
		String jobId = sc.getStdout().trim();

		sc = new ShellCommand("qstat", "-x", jobId);
		if (sc.isError()) {
			throw new InternalException("Unable to query just submitted job (id " + jobId + ") via qstat "
					+ sc.getStderr());
		}
		String jobsXml = sc.getStdout().trim();

		Qstat qstat;
		try {
			qstat = (Qstat) qstatUnmarshaller.unmarshal(new StringReader(jobsXml));
		} catch (JAXBException e1) {
			throw new InternalException("Unable to parse qstat output for job (id " + jobId + ") " + sc.getStderr());
		}
		for (Qstat.Job xjob : qstat.getJobs()) {
			String id = xjob.getJobId();
			if (id.equals(jobId)) {
				String wn = xjob.getWorkerNode();
				String workerNode = wn != null ? wn.split("/")[0] : "";
				R92Job job = new R92Job();
				job.setId(jobId);
				job.setStatus(xjob.getStatus());
				job.setBatchUsername(owner);
				job.setUsername(username);
				job.setSubmitDate(new Date());
				job.setBatchFilename(batchScriptFile.toFile().getName());
				job.setWorkerNode(workerNode);
				job.setExecutable(executable);
				entityManager.persist(job);
			}
		}
		return jobId;
	}

	private void createScript(Path batchScriptFile, List<String> parameters, String executable)
			throws InternalException {

		try (BufferedWriter bw = Files.newBufferedWriter(batchScriptFile, Charset.forName("UTF-8"))) {
			bw.write("#!/bin/sh");
			bw.newLine();
			bw.write("echo $(date) - " + executable + " starting");
			bw.newLine();
			String line = executable + " " + JobManagementBean.escaped(parameters);
			logger.debug("Exec line for " + executable + ": " + line);
			bw.write(line);
			bw.newLine();
			bw.newLine();
		} catch (IOException e) {
			throw new InternalException("Exception creating batch script: " + e.getMessage());
		}
		batchScriptFile.toFile().setExecutable(true);

	}

	private static String sq = "\"'\"";

	static String escaped(List<String> parameters) {
		StringBuilder sb = new StringBuilder();
		for (String parameter : parameters) {
			if (sb.length() != 0) {
				sb.append(" ");
			}
			int offset = 0;
			while (true) {
				int quote = parameter.indexOf('\'', offset);
				if (quote == offset) {
					sb.append(sq);
				} else if (quote > offset) {
					sb.append("'" + parameter.substring(offset, quote) + "'" + sq);
				} else if (offset != parameter.length()) {
					sb.append("'" + parameter.substring(offset) + "'");
					break;
				} else {
					break;
				}
				offset = quote + 1;
			}
		}
		return sb.toString();
	}

	public R92Account submitInteractive(String username, String executable, List<String> parameters, String family)
			throws InternalException {
		Path interactiveScriptFile = null;
		try {
			interactiveScriptFile = Files.createTempFile(null, null);
		} catch (IOException e) {
			throw new InternalException("Unable to create a temporary file: " + e.getMessage());
		}
		createScript(interactiveScriptFile, parameters, executable);
		return machineEJB.prepareMachine(executable, parameters, interactiveScriptFile);
	}

	private String getUserName(String sessionId, String icatUrl) throws ParameterException, SessionException {
		try {
			checkCredentials(sessionId, icatUrl);
			ICATService service = new ICATService(new URL(new URL(icatUrl), "ICATService/ICAT?wsdl"), qName);
			return service.getICATPort().getUserName(sessionId);
		} catch (IcatException_Exception e) {
			if (e.getFaultInfo().getType() == IcatExceptionType.SESSION) {
				throw new SessionException("IcatException " + e.getFaultInfo().getType() + " " + e.getMessage());
			} else {
				throw new ParameterException("IcatException " + e.getFaultInfo().getType() + " " + e.getMessage());
			}
		} catch (MalformedURLException e) {
			throw new ParameterException("Bad URL " + e.getMessage());
		}
	}

	public String list(String sessionId, String icatUrl) throws SessionException, ParameterException {
		logger.info("list called with sessionId:" + sessionId);
		String username = getUserName(sessionId, icatUrl);
		List<String> jobs = entityManager.createNamedQuery(R92Job.ID_BY_USERNAME, String.class)
				.setParameter("username", username).getResultList();
		return BatchJson.list(jobs);
	}

	public String getStatus(String jobId, String sessionId, String icatUrl) throws SessionException,
			ForbiddenException, InternalException, ParameterException {
		logger.info("getStatus called with sessionId:" + sessionId + " jobId:" + jobId);
		R92Job job = getJob(jobId, sessionId, icatUrl);
		JobStatus jobStatus = statusMapper.get(job.getStatus());
		if (jobStatus == null) {
			throw new InternalException("Status " + job.getStatus() + " is not recognised");
		}
		return BatchJson.getStatus(jobStatus);
	}

	private R92Job getJob(String jobId, String sessionId, String icatUrl) throws SessionException, ForbiddenException,
			ParameterException {
		String username = getUserName(sessionId, icatUrl);
		R92Job job = entityManager.find(R92Job.class, jobId);
		if (job == null || !job.getUsername().equals(username)) {
			throw new ForbiddenException("Job does not belong to you");
		}
		return job;
	}

	public void delete(String jobId, String sessionId, String icatUrl) throws SessionException, ForbiddenException,
			InternalException, ParameterException {
		logger.info("delete called with sessionId:" + sessionId + " jobId:" + jobId);
		R92Job job = getJob(jobId, sessionId, icatUrl);
		if (!job.getStatus().equals("C")) {
			throw new ParameterException("Only completed jobs can be deleted - try cancelling first");
		}
		for (String oe : new String[] { "o", "e" }) {
			String ext = "." + oe + jobId.split("\\.")[0];
			Path path = FileSystems.getDefault().getPath("/home/batch/jobs", job.getBatchFilename() + ext);
			try {
				Files.deleteIfExists(path);
			} catch (IOException e) {
				throw new InternalException("Unable to delete " + path.toString());
			}
		}
		entityManager.remove(job);
	}

	public void cancel(String jobId, String sessionId, String icatUrl) throws SessionException, ForbiddenException,
			InternalException, ParameterException {
		logger.info("cancel called with sessionId:" + sessionId + " jobId:" + jobId);
		R92Job job = getJob(jobId, sessionId, icatUrl);
		ShellCommand sc = new ShellCommand("qdel", job.getId());
		if (sc.isError()) {
			throw new InternalException("Unable to cancel job " + sc.getStderr());
		}

	}

	private void checkCredentials(String sessionId, String icatUrl) throws ParameterException {
		if (sessionId == null) {
			throw new ParameterException("No sessionId was specified");
		}
		if (icatUrl == null) {
			throw new ParameterException("No icatUrl was specified");
		}
	}

	public String submit(String executable, List<String> parameters, String family, boolean interactive,
			String sessionId, String icatUrl) throws InternalException, SessionException, ParameterException {
		logger.info("submit called with sessionId:" + sessionId + " executable:" + executable + " parameters:"
				+ parameters + " family:" + family + " :" + " interactive:" + interactive);
		String userName = getUserName(sessionId, icatUrl);
		if (interactive) {
			R92Account account = submitInteractive(userName, executable, parameters, family);
			return BatchJson.submitRDP(machineEJB.getPoolPrefix() + account.getId(), account.getPassword(),
					account.getHost());
		} else {
			return BatchJson.submitBatch(submitBatch(userName, executable, parameters, family));
		}
	}

	public String estimate(String executable, List<String> parameters, String family, boolean interactive,
			String sessionId, String icatUrl) throws SessionException, ParameterException {
		logger.info("estimate called with sessionId:" + sessionId + " executable:" + executable + " parameters:"
				+ parameters + " family:" + family + " :" + " interactive:" + interactive);
		String userName = getUserName(sessionId, icatUrl);

		if (interactive) {
			return BatchJson.estimate(estimateInteractive(userName, executable, parameters, family));
		} else {
			return BatchJson.estimate(estimateBatch(userName, executable, parameters, family));
		}
	}

	private int estimateBatch(String userName, String executable, List<String> parameters, String family) {
		return 0;
	}

	private int estimateInteractive(String userName, String executable, List<String> parameters, String family) {
		return 0;
	}

}
