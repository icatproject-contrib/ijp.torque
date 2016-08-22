#
# Base_site
# (2015-11-17: Based on original base_lsf)
# 2016-08-18: fix 'require' value on mount /mnt/Octopus; remove OctopusA/B and nfs.credentials
# 2016-08-22: move /mnt/Octopus to server_site - not needed on worker nodes
#
class base_site {
 
  group {"octopus":
    ensure => "present",
    gid => "1050",
  }
  
  package {"cifs-utils":
    ensure => present,
  }
  
  package {"nfs-common":
  	ensure => present,
  }
  
}
