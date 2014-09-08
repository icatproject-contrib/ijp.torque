#
# Worker
#
class worker {
  include nagios::target
  include torque::worker
  include ganglia::reporter

  sudoers_entry { "dmf_on_worker": }

  sudoers_entry { "batch_on_worker": }

  package { "xrdp": ensure => present, }

  package { "openbox": ensure => "present", }

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

  class { "apt":
    always_apt_update    => true,
    disable_keys         => undef,
    proxy_host           => false,
    proxy_port           => '8080',
    purge_sources_list   => false,
    purge_sources_list_d => false,
    purge_preferences_d  => false
  }

  apt::source { "octopus-apt":
    location => "http://apt.fbi-octopus.org.uk/",
    release  => "precise",
    repos    => "main",
  }

  package { "lola-analysis-suite":
    ensure  => "latest",
    require => Apt::Source["octopus-apt"],
  }

  file { "/opt/ijp/bin":
    source  => "puppet:///modules/worker/opt/ijp/bin",
    recurse => true,
    purge   => false,
    mode    => "0755"
  }

  file { ["/opt/", "/opt/ijp"]: ensure => "directory", }

}
