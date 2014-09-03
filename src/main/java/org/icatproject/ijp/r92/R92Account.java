package org.icatproject.ijp.r92;

import java.util.Date;

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.NamedQueries;
import javax.persistence.NamedQuery;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Transient;

@Entity
@NamedQueries({
		@NamedQuery(name = R92Account.TODELETE, query = "SELECT a FROM R92Account a WHERE a.allocatedDate IS NULL"),
		@NamedQuery(name = R92Account.OLD, query = "SELECT a FROM R92Account a WHERE a.allocatedDate < :date"),
		@NamedQuery(name = R92Account.USERS, query = "SELECT COUNT(a) FROM R92Account a WHERE a.host = :host") })
public class R92Account {

	public static final String TODELETE = "R92Account.TODELETE"; // Accounts which might be deleted
	public static final String OLD = "R92Account.OLD"; // Expired accounts
	public static final String USERS = "R92Account.USERS"; // Count of users on host

	@Id
	@GeneratedValue
	private long id;

	private String host;

	@Transient
	private String password;

	private String userName;

	@Temporal(TemporalType.TIMESTAMP)
	private Date allocatedDate;

	// Needed for JPA
	public R92Account() {
	}

	public String getHost() {
		return host;
	}

	public void setHost(String host) {
		this.host = host;
	}

	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	public String getPassword() {
		return password;
	}

	public void setPassword(String password) {
		this.password = password;
	}

	public String getUserName() {
		return userName;
	}

	public void setUserName(String userName) {
		this.userName = userName;
	}

	public Date getAllocatedDate() {
		return allocatedDate;
	}

	public void setAllocatedDate(Date allocatedDate) {
		this.allocatedDate = allocatedDate;
	}

}