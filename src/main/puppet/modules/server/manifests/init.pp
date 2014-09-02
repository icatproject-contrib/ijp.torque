#
# Server
#
class server {

  include torque::server
  include nagios::monitor
  include ganglia::web
  include ganglia::reporter
  include apache2
  include glassfish::server
 
  exec {"tar zxf /root/downloads/ijp-utils-1.0.0.tar.gz main/python/ijp --to-command cat > /usr/local/bin/ijp && chmod 775 /usr/local/bin/ijp":
  	creates => "/usr/local/bin/ijp",
  	path => ["/bin"],
  }
  
  file {"/etc/puppet/modules/server/files/python":
  	ensure => directory,
  }
  
  file {"/etc/puppet/modules/server/files/python/python-ijp-1.0.0.tar.gz":
  	source => "/root/downloads/python-ijp-1.0.0.tar.gz",
  }
   
  file {"/etc/puppet/modules/usergen/manifests/":
  	ensure => "directory",
  	owner => "dmf",
  	group => "dmf",
  	require => Common_account["dmf"],
  }
  
  file {"/etc/puppet/modules/usergen/manifests/init.pp":
  	ensure => "file",
  	owner => "dmf",
  	group => "dmf",
  	require => User["dmf"],
  }
  
   file {"/home/dmf/bin/wakeup":
    ensure => "file",
    source => "puppet:///modules/server/wakeup", 
    owner => "dmf",
    group => "dmf",
    mode => "0500",
    require => User[ "dmf" ],
  }

  firewall { "100 open port 8140 for puppet":
    proto => tcp,
    port => 8140,
    action => accept,
  }

  firewall { "100 open port 5432 for postgresql":
    proto => tcp,
    port => 5432,
    action => accept,
  }
 
  firewall { "100 open port 8081 for puppetdb":
    proto => tcp,
    port => 8081,
    action => accept,
  }
  
  firewall { "100 open port 4848 for glassfish admin":
    proto => tcp,
    port => 4848,
    action => accept,
  }
  
  firewall { "100 open port 8080 for glassfish":
    proto => tcp,
    port => 8080,
    action => accept,
  }
  
  firewall { "100 open port 1099 for puppetdb - this one is not understood":
    proto => tcp,
    port => 1099,
    action => accept,
  }
       
  file {"dmf.profile":
    ensure => present,
    path => "/home/dmf/.profile",
    source => "puppet:///modules/server/dmf.profile",
    owner => "dmf",
    group => "dmf",
    require => User["dmf"],
  }
  
  file {"dmf.portal_submissions":
    ensure => directory,
    path => "/home/dmf/portal_submissions",
    owner => "dmf",
    group => "dmf",
    require => User["dmf"],
  }

  sudoers_entry{"dmf_on_server":}

  file {"/etc/security/limits.conf":
    ensure => "file",
    source => "puppet:///modules/server/etc/security/limits.conf",
    owner => "root",
    group => "root",
    mode => "0644",
  }

  file {"/etc/pam.d/su":
    ensure => "file",
    source => "puppet:///modules/server/etc/pam.d/su",
    owner => "root",
    group => "root",
    mode => "0644",
  }
   
}