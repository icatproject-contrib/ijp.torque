#
# Worker
#
class worker {

  include nagios::target
  include torque::worker
  include ganglia::reporter

  sudoers_entry{"dmf_on_worker":
  }
  
  sudoers_entry{"batch_on_worker":
  }

  package {"xrdp":
    ensure => present,
  }
  
  package {"openbox":
  	ensure => "present",
  }
  
  file {"/usr/local/sbin/push_output":
    ensure => "file",
    source => "puppet:///modules/worker/push_output",
    owner => "root",
    group => "root",
    mode => "0500",
  }
    
  file {"/home/dmf/bin/prepareaccount":
    ensure => "file",
    source => "puppet:///modules/worker/prepareaccount", 
    owner => "dmf",
    group => "dmf",
    mode => "0500",
    require => User[ "dmf" ],
  }
  
  service {"xrdp":
    ensure => running,
    enable => true,
  }

  firewall { "100 open port 3389 for xrdp":
    ensure => present,
    proto => tcp,
    port => 3389,
    action => accept,
  }
   
  # Permit unsigned packages
  file { "/etc/apt/apt.conf.d/99auth":       
    owner     => root,
    group     => root,
    content   => "APT::Get::AllowUnauthenticated yes;",
    mode      => 644;
  }
  
  # Store for python distros
  file {"/root/python-pkgs/": 
  	source => "puppet:///modules/server/python",
    recurse => true,
    purge => true,
  }
  
  # Simple python installer
  file {"/usr/sbin/install_python_packages":
  	source => "puppet:///modules/server/usr/sbin/install_python_packages",
  	mode => 755,
  }
  
  exec {"/usr/sbin/install_python_packages":
    subscribe => File["/root/python-pkgs/"],
 	refreshonly => true,
  }
  
    file { "ids.client-distro.zip":
    path    => "/home/dmf/install/distro/ids.client-distro.zip",
    source  => "puppet:///modules/glassfish/distros/ids.client-1.0.0-distro.zip",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  exec { "ids.client":
    command     => "${base::deploy} root ids.client ids.client-distro.zip",
    subscribe   => File["ids.client-distro.zip"],
    refreshonly => true,
  }

}
