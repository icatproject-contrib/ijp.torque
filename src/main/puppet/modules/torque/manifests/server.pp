#
# torque
#
class torque::server {

  service {"pbs_sched":
    ensure => running,
    hasstatus => false,
    enable => true,
  }
  
  file {"/etc/torque":
  	ensure => "directory",
  }

  file {"/etc/torque/server_name":
    content => "$fqdn",
    ensure => present,
    notify => Service["pbs_server"],
  }
  
  file { "/var/spool/torque/server_name":
    ensure => "link",
    target => "/etc/torque/server_name",
    require => Exec["pbs_server_package"],
  }
  
  @@file {"/etc/torque/server_name-export":
  	path => "/etc/torque/server_name",
    content => "$fqdn",
    ensure => present,
    notify => Service["pbs_mom"],
  }

  service {"pbs_server":
    ensure => running,
    hasstatus => false,
    enable => true, 
    require => Exec["pbs_server_package"],
  }
  
  file {"/usr/local/etc/torque-package-server-linux-x86_64.sh":
  	ensure => "file",
  	source => "puppet:///modules/torque/distros/torque-package-server-linux-x86_64.sh",
  	mode => "0500",
  } 
  
  file {"/usr/local/etc/torque-package-clients-linux-x86_64.sh":
  	ensure => "file",
  	source => "puppet:///modules/torque/distros/torque-package-clients-linux-x86_64.sh",
  	mode => "0500",
  }
  
  exec {"pbs_server_package":
  	command => "/usr/local/etc/torque-package-server-linux-x86_64.sh --install && pbs_server -t create",
  	creates => "/var/spool/torque/server_priv",
  }
  
  exec {"pbs_clients_package":
  	command => "/usr/local/etc/torque-package-clients-linux-x86_64.sh --install",
  	creates => "/var/spool/torque/server_priv",
  }
  
  file {"/etc/init.d/pbs_server":	
    ensure => "file",
  	source => "puppet:///modules/torque/distros/pbs_server",
  	mode => "0755",
  }
  
  file {"/etc/init.d/pbs_sched":	
    ensure => "file",
  	source => "puppet:///modules/torque/distros/pbs_sched",
  	mode => "0755",
  }
  
  exec {"pbs_server_service":
  	command => "update-rc.d pbs_server defaults",
  	path => "/usr/sbin",
  	creates  => "/etc/rc3.d/S20pbs_server",
  	require => File["/etc/init.d/pbs_server"],
  }
  
  exec {"pbs_sched_service":
  	command => "update-rc.d pbs_sched defaults",
  	path => "/usr/sbin",
  	creates  => "/etc/rc3.d/S20pbs_sched",
  	require => File["/etc/init.d/pbs_sched"],
  }
  
  concat {"/var/spool/torque/server_priv/nodes":
    notify => Service ["pbs_server"],
  }

  Concat::Fragment <<| tag == "torque_worker" |>>
  
  file {"qmgr.sh":
    path => "/usr/sbin/qmgr.sh",
  	source => "puppet:///modules/torque/usr/sbin/qmgr.sh",
  	mode => "0755",
  	notify => Exec["/var/spool/torque/qmgred","qmgr.sh"]
  }
  
  exec {"/var/spool/torque/qmgred":
    command => "rm -f /var/spool/torque/qmgred",
  	path => "/bin",
    refreshonly => true,
    notify => Exec["qmgr.sh"]
  }
  
  exec {"qmgr.sh":
  	path => ["/usr/sbin","/bin","/usr/local/bin","/usr/bin"],
  	creates  => "/var/spool/torque/qmgred",
  	notify => Service["pbs_server"],
  	require => [File["qmgr.sh"],Exec["pbs_server_package", "pbs_clients_package"]],
  }
 
}
