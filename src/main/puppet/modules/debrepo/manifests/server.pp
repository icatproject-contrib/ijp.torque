class debrepo::server {
  
   package { ["reprepro"]:
     ensure => installed,
   }
   
   file { "/etc/debrepo":
   	 ensure => directory,
   }  
   
   file { "/etc/debrepo/conf":
   	 ensure => directory,
   }
   
   file { "/etc/apache2/conf.d/debs.conf":
   	  ensure => file,
   	  source => "puppet:///modules/debrepo/debs.conf",
   	  notify => Service["apache2"],
   }
   
   file { "/etc/debrepo/conf/distributions":
   	 ensure => file,
   	 source => "puppet:///modules/debrepo/conf/distributions",
     mode => "0644",
     owner => "root",
     group => "root",
   }
   
    @@file {"/etc/apt/sources.list.d/ijp.list":
    content => "deb http://$fqdn/debs ijp main\n",
    ensure => present, 
   
  }
   
   
}
