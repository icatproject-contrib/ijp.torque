package org.icatproject.ijp.r92;

public class Constants {
	public static final String PROPERTIES_FILEPATH = "r92.properties";
	public static final String DMF_WORKING_DIR_NAME = "/home/dmf/submissions";
	
	// Location of puppet modules has changed (2016-06-20) with new version of Puppet and/or move to RHEL;
	// new location appears to be:
	// public static final String USERGEN = "/etc/puppetlabs/code/environments/production/modules/usergen/manifests/init.pp";
	// However, other problems with the RHEL installation discourage from continuing.
	// For original installation on Ubuntu, use the following:
	public static final String USERGEN = "/etc/puppet/modules/usergen/manifests/init.pp";
}
