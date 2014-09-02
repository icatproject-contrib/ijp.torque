class ganglia::web {

    package { ["ganglia-webfrontend"]:
     ensure => installed,
   }

   service { "gmetad":
     ensure => running,
     enable => true,
     hasstatus => false,
     subscribe => Package["ganglia-webfrontend"],
   }

   file {"/etc/apache2/sites-enabled/ganglia.conf":
     source => "/etc/ganglia-webfrontend/apache.conf",
     ensure => present,
     notify => Service ["apache2"]
   }

   file {"/etc/ganglia/gmetad.conf":
     source => "puppet:///modules/ganglia/gmetad.conf",
     notify => Service ["gmetad"],
   }
  
}
