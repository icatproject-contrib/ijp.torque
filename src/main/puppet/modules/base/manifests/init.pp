#
# Base
#
class base {
  include usergen
  include glassfish::client

  file { "/etc/adduser.conf":
    source => "puppet:///modules/base/etc/adduser.conf",
    mode   => "0644",
  }

  common_account { "dmf":
    ensure  => present,
    groups  => "batch",
    require => Common_account["batch"],
  }

  common_account { "batch":
    ensure => present,
    groups => [],
  }

  file { "/home/dmf/bin":
    ensure  => "directory",
    owner   => "dmf",
    group   => "dmf",
    mode    => "0700",
    require => User["dmf"],
  }

  file { "/home/batch/jobs":
    ensure  => directory,
    owner   => "batch",
    group   => "dmf",
    mode    => "0775",
    require => Common_account["batch", "dmf"],
  }

  firewall { "000 allow related and established":
    ensure => present,
    state  => [RELATED, ESTABLISHED],
    action => accept,
  }

  firewall { "000 icmp":
    ensure => present,
    proto  => icmp,
    action => accept,
  }

  firewall { "000 lo":
    ensure  => present,
    iniface => lo,
    proto   => all,
    action  => accept,
  }

  firewall { "100 open port 22 for ssh":
    ensure => present,
    proto  => tcp,
    port   => 22,
    action => accept,
  }

  firewall { "100 open port 15001 for torque":
    ensure => present,
    proto  => tcp,
    port   => 15001,
    action => accept,
  }

  firewall { "100 open port 15002 for torque":
    ensure => present,
    proto  => tcp,
    port   => 15002,
    action => accept,
  }

  firewall { "100 open port 15003 for torque":
    ensure => present,
    proto  => tcp,
    port   => 15003,
    action => accept,
  }

  firewall { "100 open port 15004 for torque":
    ensure => present,
    proto  => tcp,
    port   => 15004,
    action => accept,
  }

  #  firewall { "999 reject the rest":
  #    ensure => present,
  #    action => reject,
  #    proto => all,
  #  }

  @@sshkey { "${fqdn}_rsa":
    host_aliases => ["$fqdn", "$hostname", "$ipaddress"],
    type         => rsa,
    key          => $sshrsakey
  }

  @@sshkey { "${fqdn}_dsa":
    host_aliases => ["$fqdn", "$hostname", "$ipaddress"],
    type         => dsa,
    key          => $sshdsakey
  }

  file { "/etc/ssh/ssh_known_hosts":
    mode  => "0644",
    owner => "root",
    group => "root",
  }

  Sshkey <<| |>> {
    ensure => present
  }

  package { "python-suds": ensure => present, }

  # Hack suds
  file { "/usr/share/pyshared/suds/cache.py": source => "puppet:///modules/base/cache.py", }

  package { "ntp": ensure => present, }

  service { "ntp":
    ensure => running,
    enable => true,
  }

  package { "deja-dup": ensure => absent, }

  file { "/etc/xdg/autostart/deja-dup-monitor.desktop": ensure => absent, }
  
    $deploy = "/home/dmf/bin/deploy"

  file { ["/home/dmf/install", "/home/dmf/install/config", "/home/dmf/install/distro", "/home/dmf/install/unpack"]:
    ensure  => directory,
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "/home/dmf/bin/deploy":
    source => "puppet:///modules/glassfish/bin/deploy",
    owner  => dmf,
    group  => dmf,
    mode   => 0700,
  }
  

}
