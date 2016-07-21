#
# Base_site
# (2015-11-17: Based on original base_lsf)
#
class base_site {
 
  group {"octopus":
    ensure => "present",
    gid => "1050",
  }
  
  file { "/mnt/Octopus":
    ensure => "directory",
  }

  file { "/mnt/OctopusA":
    ensure => "directory",
  }

  file { "/mnt/OctopusB":
    ensure => "directory",
  }

  file { "/etc/nfs.credentials":
    ensure => "file",
    source => "puppet:///modules/worker_site/nfs.credentials",
    mode => "0400",
    owner => "root",
    group => "root",
  }
  
  package {"cifs-utils":
    ensure => present,
  }
  
  package {"nfs-common":
  	ensure => present,
  }
  
  mount { "/mnt/Octopus":
  	device => "penfold.ads.rl.ac.uk:/data_ext4_01/rd_overflow/rd_over_nfs",
  	fstype => "nfs",
  	ensure => "mounted",
    options => "vers=3",
    atboot => true,
    require => [File["/mnt/OctopusA"], Package["nfs-common"]],
  }
    
  mount { "/mnt/OctopusA":
    device => "//130.246.69.5/OctopusA",
    fstype => "cifs",
  	ensure => "mounted",
    options => "defaults,ro,gid=1050,file_mode=0770,dir_mode=0770,credentials=/etc/nfs.credentials",
    atboot => true,
    require => [File["/mnt/OctopusA", "/etc/nfs.credentials"],Package["cifs-utils"]],
  }

  mount { "/mnt/OctopusB":
    device => "//130.246.69.5/OctopusB",
    fstype => "cifs",
 	ensure => "mounted",
    options => "defaults,ro,gid=1050,file_mode=0770,dir_mode=0770,credentials=/etc/nfs.credentials",
    atboot => true,
    require => [File["/mnt/OctopusB", "/etc/nfs.credentials"],Package["cifs-utils"]],
  }
  
}
