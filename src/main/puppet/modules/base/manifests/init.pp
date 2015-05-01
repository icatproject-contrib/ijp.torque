#
# Base
#
class base {
  include usergen

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
  #file { "/usr/share/pyshared/suds/cache.py": source => "puppet:///modules/base/cache.py", }
  file { "/usr/lib/python2.7/dist-packages/suds/cache.py": source => "puppet:///modules/base/cache.py", }
  
  package { "ntp": ensure => present, }

  service { "ntp":
    ensure => running,
    enable => true,
  }

  package { "deja-dup": ensure => absent, }

  file { "/etc/xdg/autostart/deja-dup-monitor.desktop": ensure => absent, }

  group { "octopus":
    ensure => "present",
    gid    => "1050",
  }

  # file { "/mnt/Octopus": ensure => "directory", }

  file { "/mnt/OctopusA": ensure => "directory", }

  file { "/mnt/OctopusB": ensure => "directory", }

  file { "/etc/nfs.credentials":
    ensure => "file",
    source => "puppet:///modules/worker/nfs.credentials",
    mode   => "0400",
    owner  => "root",
    group  => "root",
  }

  package { "cifs-utils": ensure => present, }

  package { "nfs-common": ensure => present, }

  # mount { "/mnt/Octopus":
  #  device  => "penfold.ads.rl.ac.uk:/data_ext4_01/rd_overflow/rd_over_nfs",
  #  fstype  => "nfs",
  #  ensure  => "mounted",
  #  options => "vers=3",
  #  atboot  => true,
  #  require => [File["/mnt/OctopusA"], Package["nfs-common"]],
  # }

  mount { "/mnt/OctopusA":
    device  => "//130.246.69.5/OctopusA",
    fstype  => "cifs",
    ensure  => "mounted",
    options => "defaults,ro,gid=1050,file_mode=0770,dir_mode=0770,credentials=/etc/nfs.credentials",
    atboot  => true,
    require => [File["/mnt/OctopusA", "/etc/nfs.credentials"], Package["cifs-utils"]],
  }

  mount { "/mnt/OctopusB":
    device  => "//130.246.69.5/OctopusB",
    fstype  => "cifs",
    ensure  => "mounted",
    options => "defaults,ro,gid=1050,file_mode=0770,dir_mode=0770,credentials=/etc/nfs.credentials",
    atboot  => true,
    require => [File["/mnt/OctopusB", "/etc/nfs.credentials"], Package["cifs-utils"]],
  }

}
