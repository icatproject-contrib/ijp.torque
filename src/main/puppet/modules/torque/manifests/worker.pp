class torque::worker {
  @@concat::fragment { "torque_worker_${fqdn}":
    target  => "/var/spool/torque/server_priv/nodes",
    #    content => "${fqdn} np=${processorcount}\n",
    content => "${fqdn} np=1\n",
    tag     => "torque_worker",
  }

  File <<| title == "/etc/torque/server_name-export" |>>

  file { "/etc/torque": ensure => "directory", }

  file { "/var/spool/torque/server_name":
    ensure  => "link",
    target  => "/etc/torque/server_name",
    require => Exec["pbs_mom_package"],
  }

  service { "pbs_mom":
    ensure    => running,
    hasstatus => false,
    enable    => true,
    require   => [Exec["pbs_mom_package"], File["/var/spool/torque/server_name"]],
  }

  file { "/usr/local/etc/torque-package-mom-linux-x86_64.sh":
    ensure => "file",
    source => "puppet:///modules/torque/distros/torque-package-mom-linux-x86_64.sh",
    mode   => "0500",
  }

  exec { "pbs_mom_package":
    command => "/usr/local/etc/torque-package-mom-linux-x86_64.sh --install",
    creates => "/var/spool/torque/mom_priv",
  }

  file { "/etc/init.d/pbs_mom":
    ensure => "file",
    source => "puppet:///modules/torque/distros/pbs_mom",
    mode   => "0755",
  }

  exec { "pbs_mom_service":
    command => "update-rc.d pbs_mom defaults",
    path    => "/usr/sbin",
    creates => "/etc/rc3.d/S20pbs_mom",
    require => File["/etc/init.d/pbs_mom"],
  }

  file { "/var/spool/torque/mom_priv/prologue":
    ensure  => file,
    source  => "puppet:///modules/torque/mom_priv/prologue",
    mode    => "0500",
    owner   => "root",
    group   => "root",
    require => Exec["pbs_mom_package"],
  }

  file { "/var/spool/torque/mom_priv/epilogue":
    ensure  => file,
    source  => "puppet:///modules/torque/mom_priv/epilogue",
    mode    => "0500",
    owner   => "root",
    group   => "root",
    require => Exec["pbs_mom_package"],
  }

}
