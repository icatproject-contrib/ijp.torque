#
# Worker
#
class worker {
  include nagios::target
  include torque::worker
  include ganglia::reporter

  sudoers_entry { "dmf_on_worker": }

  sudoers_entry { "batch_on_worker": }

  package { "xrdp": ensure => "present", }

  package { "openbox": ensure => "present", }

  package { "xprintidle": ensure => "present" }

  package { "x11vnc": ensure => "present" }

  package { "Websockify": ensure => "present"  }

  file { "/usr/local/bin/x11vnc_background",
    ensure => "file",
    source => "puppet:///modules/worker/x11vnc_background",
    owner => "root",
    group => "root",
    mode => "0755",
  }

  file { "/usr/local/sbin/push_output":
    ensure => "file",
    source => "puppet:///modules/worker/push_output",
    owner  => "root",
    group  => "root",
    mode   => "0500",
  }

  file { "/home/dmf/bin/prepareaccount":
    ensure  => "file",
    source  => "puppet:///modules/worker/prepareaccount",
    owner   => "dmf",
    group   => "dmf",
    mode    => "0500",
    require => User["dmf"],
  }

  file { ["/home/dmf/skel","/home/dmf/skel/template"]:
    ensure  => "directory",
    owner   => "dmf",
    group   => "dmf",
    mode    => "0755",
    require => User["dmf"],
  }

  file { "/home/dmf/skel/template/xidlekill":
    ensure => "file",
    source => "puppet:///modules/worker/xidlekill",
    owner  => "dmf",
    group  => "dmf",
    mode   => "0500",
    require => User["dmf"],
  }

  service { "xrdp":
    ensure => running,
    enable => true,
  }

  firewall { "100 open port 3389 for xrdp":
    ensure => present,
    proto  => tcp,
    port   => 3389,
    action => accept,
  }

  # Permit unsigned packages
  file { "/etc/apt/apt.conf.d/99auth":
    owner   => root,
    group   => root,
    content => "APT::Get::AllowUnauthenticated yes;",
    mode    => 644;
  }

  class { 'apt':
    update => {
      frequency => 'always',
    },
  }

  apt::source { "octopus-apt":
    location => "http://apt.octopus.clf.rl.ac.uk/",
    release  => "precise",
    repos    => "main",
  }
  
  apt::source { "octopus-apt-src":
    location => "http://apt.octopus.clf.rl.ac.uk/",
    release  => "precise",
    repos    => "main",
  }

  package { "lola-analysis-suite":
    ensure  => "latest",
    require => [Apt::Source["octopus-apt"], Apt::Source["octopus-apt-src"]],
  }

# BR: there is no /opt/ijp/bin in worker/files,
# so this rule fails.  fbi-octopus adds a valid rule to worker_lsf,
# so should it be used instead?

#  file { "/opt/ijp/bin":
#    source  => "puppet:///modules/worker/opt/ijp/bin",
#    recurse => true,
#    purge   => false,
#    mode    => "0755"
#  }

#  file { ["/opt/", "/opt/ijp"]: ensure => "directory", }

}
