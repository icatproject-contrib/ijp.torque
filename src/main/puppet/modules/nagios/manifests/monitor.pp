class nagios::monitor {

  package { ["nagios3", "nagios-nrpe-plugin"]:
    ensure => installed,
  }

  service { "nagios3":
    ensure => running,
    enable => true,
    subscribe => [Package["nagios3"], Package["nagios-nrpe-plugin"]],
  }

   Nagios_host <<||>> {
    notify => Service["nagios3"]
  }

  file {"/etc/nagios3/conf.d/puppet_nagios_host.cfg":
    mode => "0644",
    require => Package["nagios3"],
  }

}
