 class ganglia::reporter {

   package { ["ganglia-monitor"]:
     ensure => installed,
   }

   service { "ganglia-monitor":
     ensure => running,
     enable => true,
     hasstatus => false,
     pattern => "gmond",
     subscribe => Package["ganglia-monitor"],
   }
  
   firewall { "100 open port 8649 for ganglia":
     proto => tcp,
     port => 8649,
     action => accept,
   }

 }
