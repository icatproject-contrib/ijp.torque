#
# Server
#
class server {

  include torque::server
  include nagios::monitor
  include ganglia::web
  include ganglia::reporter
  include apache2
  include jdk
  
  file {"/home/dmf/install":
    ensure => "directory",
    owner => "dmf",
  	group => "dmf",
  	require => Common_account["dmf"],
  }
  
#
# 2015-11-17:
# If we follow the 'usual' ICAT installation process,
# the batch connector ijp.r92 (aka ijp.torque) will have been
# installed already, so this rule is not required.
# And wrong, as there's no ijp.r92 under server/files...
#
#  file {"/home/dmf/install/ijp.r92": 
#    ensure => "directory",
#  	source => "puppet:///modules/server/ijp.r92",
#  	recurse => "remote", 
#  	owner => "dmf",
#  	group => "dmf", 	
#  }
  	  
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
  
  file {"dmf.submissions":
    ensure => directory,
    path => "/home/dmf/submissions",
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

# 2015-11-17: BR thinks this is superseded by similar case in server_site
#  
#   if $fqdn == "rclsfserv010.rc-harwell.ac.uk" {
#
#    file { "/mnt/rhubarb": ensure => "directory", }
#
#    mount { "/mnt/rhubarb":
#      device  => "rhubarb.ads.rl.ac.uk:/vol2/rallsf",
#      fstype  => "nfs",
#      ensure  => "mounted",
#      options => "user,rsize=32768,wsize=32768,hard,intr",
#      atboot  => true,
#      require => [File["/mnt/rhubarb"], Package["nfs-common"]],
#      notify  => Exec["${ids_archive_dir}"],
#    }
#
#  } 
  
}
