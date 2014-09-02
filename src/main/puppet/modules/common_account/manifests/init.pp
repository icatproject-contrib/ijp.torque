define common_account($user = $title, $ensure, $groups) {

  if $ensure == present {
    $ensure_file = file
    $ensure_dir = directory
  } else {
    $ensure_file = $ensure
    $ensure_dir = $ensure
  }
  
  user {"$user":
    ensure => $ensure,
    managehome => true,
    groups => $groups,
    shell => "/bin/bash",
  }

  file { "/home/${user}/.ssh":
    ensure => $ensure_dir,
    mode => "0600",
    owner => "${user}",
    group => "${user}",
    require => User["${user}"],
  }
    
  file { "/home/${user}/.ssh/id_rsa":
    ensure => $ensure_file,
    source => "puppet:///modules/common_account/${user}/id_rsa",
    mode => "0600",
    owner => "${user}",
    group => "${user}",
    require => File[ "/home/${user}/.ssh" ],
  }

  file { "/home/${user}/.ssh/authorized_keys":
    ensure => $ensure_file,
    source => "puppet:///modules/common_account/${user}/authorized_keys",
    mode => "0644",
    owner => "${user}",
    group => "${user}",
    require => File[ "/home/${user}/.ssh" ],
  }
  
  file { "/home/${user}/.ssh/id_rsa.pub":
    ensure => $ensure_file,
    source => "puppet:///modules/common_account/${user}/id_rsa.pub",
    mode => "0644",
    owner => "${user}",
    group => "${user}",
    require => File[ "/home/${user}/.ssh" ],
  }

}
