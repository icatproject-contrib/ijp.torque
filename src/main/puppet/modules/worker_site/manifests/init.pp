#
# Worker_site
# 2015-11-17 : adapted from worker_lsf
#

class worker_site {

# apt and octopus-apt are defined (better?) in the worker module
# (BR, 2015-11-17)
#
#  class { "apt":
#    always_apt_update    => true,
#    disable_keys         => undef,
#    proxy_host           => false,
#    proxy_port           => '8080',
#    purge_sources_list   => false,
#    purge_sources_list_d => false,
#    purge_preferences_d  => false
#  }
#  
#  apt::source { "octopus-apt":
#    location          => "http://apt.fbi-octopus.org.uk/",
#    release           => "precise",
#    repos             => "main",
#  }
#  
#  package {"lola-analysis-suite":
#  	ensure => "latest",
#  	require => Apt::Source["octopus-apt"],
#  }
  
  file { "/opt/ijp/bin":
    source => "puppet:///modules/worker_site/opt/ijp/bin",
    recurse => true,
    purge => false,
    mode => "0755"
  }
  
  file { [ "/opt/", "/opt/ijp" ]:
    ensure => "directory",
  }
  
}
