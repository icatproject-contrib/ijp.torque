package org.icatproject.ijp.r92;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Random;
import java.util.Set;

import javax.annotation.PostConstruct;
import javax.ejb.Schedule;
import javax.ejb.Stateless;
import javax.persistence.EntityManager;
import javax.persistence.LockModeType;
import javax.persistence.PersistenceContext;

import org.icatproject.ijp.batch.exceptions.InternalException;
import org.icatproject.utils.CheckedProperties;
import org.icatproject.utils.CheckedProperties.CheckedPropertyException;
import org.icatproject.utils.ShellCommand;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Stateless
public class MachineEJB {

	final static Logger logger = LoggerFactory.getLogger(MachineEJB.class);

	private long passwordDurationMillis;

	private String prepareaccount;
	private int idleTimeout;
	private int warnDelay;
	
	private final static int DEFAULT_IDLE_TIMEOUT = 600;
	private final static int DEFAULT_WARN_DELAY = 60;

	private LoadFinder loadFinder;

	@PostConstruct
	private void init() {
		CheckedProperties props = new CheckedProperties();
		try {
			props.loadFromFile(Constants.PROPERTIES_FILEPATH);
			passwordDurationMillis = props.getPositiveInt("passwordDurationSeconds") * 1000L;
			poolPrefix = props.getString("poolPrefix");
			prepareaccount = props.getString("prepareaccount");
			if( props.has("idleTimeout") ){
				idleTimeout = props.getPositiveInt("idleTimeout");
			} else {
				idleTimeout = DEFAULT_IDLE_TIMEOUT;
			}
			if( props.has("warnDelay") ){
				warnDelay = props.getPositiveInt("warnDelay");
			} else {
				warnDelay = DEFAULT_WARN_DELAY;
			}
			logger.debug("Machine Manager Initialised");
		} catch (CheckedPropertyException e) {
			throw new RuntimeException("CheckedPropertyException " + e.getMessage());
		}
		try {
			pbs = new Pbs();
			loadFinder = new LoadFinder();
			pbs = new Pbs();
		} catch (InternalException e) {
			throw new RuntimeException("ServerException " + e.getMessage());
		}
	}

	@PersistenceContext(unitName = "r92")
	private EntityManager entityManager;

	private String poolPrefix;

	private Pbs pbs;

	private final static Random random = new Random();
	private final static String chars = "abcdefghijkmnpqrstuvwxyz23456789";

	private R92Account getAccount(String lightest, String jobName, List<String> parameters,
			Path script) throws InternalException {
		logger.debug("Set up a pool account on " + lightest);

		R92Account account = new R92Account();
		account.setHost(lightest);
		entityManager.persist(account);
		char[] pw = new char[4];
		for (int i = 0; i < pw.length; i++) {
			pw[i] = chars.charAt(random.nextInt(chars.length()));
		}
		String password = new String(pw);

		Long id = account.getId();

		ShellCommand sc = new ShellCommand("scp", script.toAbsolutePath().toString(), "dmf@"
				+ lightest + ":" + id + ".sh");
		if (sc.isError()) {
			throw new InternalException(sc.getMessage());
		}

		prepareVnc(lightest, password, id);

		List<String> args = Arrays.asList("ssh", lightest, prepareaccount, poolPrefix + id,
				password, id + ".sh", String.valueOf(idleTimeout), String.valueOf(warnDelay));
		sc = new ShellCommand(args);
		if (sc.isError()) {
			throw new InternalException(sc.getMessage());
		}
		if (!sc.getStdout().isEmpty()) {
			logger.debug("Prepare account reports " + sc.getStdout());
		}
		account.setAllocatedDate(new Date());

		account.setPassword(password);

		return account;
	}

	private void prepareVnc(String lightest, String password, Long id) throws InternalException {
		ShellCommand sc;List<String> args = Arrays.asList("ssh", lightest, prepareaccount, poolPrefix + id,
				password, "/usr/local/bin/x11vnc_background " + password + " &",
				String.valueOf(idleTimeout), String.valueOf(warnDelay));
		sc = new ShellCommand(args);
		if (sc.isError()) {
			throw new InternalException(sc.getMessage());
		}
	}

	@Schedule(minute = "*/1", hour = "*")
	private void cleanAccounts() {
		try {
			/* First find old accounts and remove their password */
			Date passwordTime = new Date(System.currentTimeMillis() - passwordDurationMillis);
			List<R92Account> accounts = entityManager
					.createNamedQuery(R92Account.OLD, R92Account.class)
					.setParameter("date", passwordTime).getResultList();
			for (R92Account account : accounts) {
				entityManager.refresh(account, LockModeType.PESSIMISTIC_WRITE);
				logger.debug("Delete password for account " + account.getId() + " on "
						+ account.getHost());
				ShellCommand sc = new ShellCommand("ssh", account.getHost(), "sudo",
						"/usr/bin/passwd", "-d", poolPrefix + account.getId());
				if (sc.isError()) {
					throw new RuntimeException(sc.getMessage());
				}
				logger.debug("Command passwd reports " + sc.getStdout());
				account.setAllocatedDate(null);
			}

			/* Now delete any accounts which have no processes running */
			accounts = entityManager.createNamedQuery(R92Account.TODELETE, R92Account.class)
					.getResultList();
			boolean deleted = false;
			for (R92Account account : accounts) {
				ShellCommand sc = new ShellCommand("ssh", account.getHost(), "ps", "-F",
						"--noheaders", "-U", poolPrefix + account.getId());
				if (sc.getExitValue() == 1
						&& sc.getStderr().toLowerCase().startsWith("error: user name does not exist")) {
					/* Account seems to have vanished */
					entityManager.remove(account);
					deleted = true;
					logger.warn("Account for " + poolPrefix + account.getId() + " on "
							+ account.getHost() + " has vanished!");
				} else if (!sc.getStderr().isEmpty()) {
					/* Odd condition because no processes has error code 1 */
					logger.error("Unexpected problem using ssh to connect to " + account.getHost()
							+ " to find proceeses for " + poolPrefix + account.getId());
					throw new RuntimeException(sc.getMessage());
				} else if (sc.getStdout().isEmpty()) {
					logger.debug("No processes running for " + poolPrefix + account.getId() + " on " + account.getHost());
					sc = new ShellCommand("ssh", account.getHost(), "sudo", "userdel", "-r",
							poolPrefix + account.getId());
					if (sc.isError()) {
						// BR, 2016-07-22: originally this threw a RuntimeException;
						// but I think this is too extreme: (a) it is being triggered
						// when there is no /var/mail/poolNNN directory; and (b) it prevents
						// cleanup of other accounts (as we're in a loop here).
						// So I have replaced the throw with a warning
						logger.warn("userdel for " + poolPrefix + account.getId() + " on " + account.getHost() + " reported error: '" + sc.getMessage()
								+ "'; but will assume it is OK to remove the account.");
					}
					logger.debug("Command userdel for " + poolPrefix + account.getId() + " on "
							+ account.getHost() + " reports " + sc.getStdout());
					entityManager.remove(account);
					deleted = true;
				} else {
					logger.debug(poolPrefix + account.getId() + " has "
							+ sc.getStdout().split("\\n").length + " processes running on "
							+ account.getHost());
				}
			}

			/*
			 * If an account was deleted consider putting machines back on line. This checks all
			 * machines not only the one for which the account was deleted to help recover if the
			 * system gets into a strange state.
			 */
			if (deleted) {
				Map<String, String> avail = pbs.getStates();
				for (Entry<String, String> pair : avail.entrySet()) {
					boolean online = true;
					for (String state : pair.getValue().split(",")) {
						if (state.equals("offline")) {
							online = false;
							break;
						}
					}
					if (!online) {
						String hostName = pair.getKey();
						long count = entityManager.createNamedQuery(R92Account.USERS, Long.class)
								.setParameter("host", hostName).getSingleResult();
						if (count == 0L) {
							logger.debug("Idle machine " + hostName + " has no users");
							pbs.setOnline(hostName);
						} else {
							logger.debug("Idle machine " + hostName + " has " + count
									+ " users so cannot be put back online");
						}
					}
				}
			}

		} catch (Throwable e) {
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			PrintStream ps = new PrintStream(baos);
			e.printStackTrace(ps);
			logger.error("cleanAccounts failed " + baos.toString());
		}
	}

	public R92Account prepareMachine(String jobName, List<String> parameters, Path script)
			throws InternalException {
		Set<String> machines = new HashSet<String>();
		Map<String, Float> loads = loadFinder.getLoads();
		if( loads == null || loads.size() == 0 ){
			logger.warn("prepareMachine: no loads returned by LoadFinder");
		}
		Map<String, String> avail = pbs.getStates();
		for (Entry<String, String> pair : avail.entrySet()) {
			boolean online = true;
			for (String state : pair.getValue().split(",")) {
				if (state.equals("offline") || state.equals("down")) {
					logger.debug(pair.getKey() + " is currently " + state);
					online = false;
					break;
				}
			}
			if (online) {
				logger.debug(pair.getKey() + " is currently online");
				machines.add(pair.getKey());
			}
		}
		if (machines.isEmpty()) {
			machines = avail.keySet();
			if (machines.isEmpty()) {
				throw new InternalException("No machines available");
			}
		}

		String lightest = null;
		for (String machine : machines) {
			// BR, 2016-07-25 : NPE seen in the loads comparison;
			// add logging and workaround - behave as though the machine is saturated.
			// (This assumes that the load value is a percentage.)
			if( loads == null || loads.get(machine) == null ){
				logger.warn("prepareMachine: no load defined for " + machine +"; set load to 100.0");
				loads.put(machine, new Float(100.0));
			} else {
				logger.debug("prepareMachine: load for " + machine + " = " + loads.get(machine));
			}
			if (lightest == null || loads.get(machine) < loads.get(lightest)) {
				lightest = machine;
			}
		}

		pbs.setOffline(lightest);
		return getAccount(lightest, jobName, parameters, script);

	}

	public String getPoolPrefix() {
		return poolPrefix;
	}
}
