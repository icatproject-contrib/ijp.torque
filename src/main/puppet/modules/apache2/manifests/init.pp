class apache2 {
  package { ["apache2"]: ensure => installed, }

  service { "apache2":
    ensure    => running,
    enable    => true,
    subscribe => Package["apache2"],
  }

  firewall { "100 open port 80 for apache":
    proto  => tcp,
    port   => 80,
    action => accept,
  }

}
