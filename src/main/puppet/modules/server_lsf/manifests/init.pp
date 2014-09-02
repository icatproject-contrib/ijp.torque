#
# Server_lsf
#
class server_lsf {
  if $fqdn == "rclsfserv010.rc-harwell.ac.uk" {
    $ids_main_dir = "/mnt/data/ids"
    $ids_archive_dir = "/mnt/rhubarb/ids"

    file { "/mnt/rhubarb": ensure => "directory", }

    mount { "/mnt/rhubarb":
      device  => "rhubarb.ads.rl.ac.uk:/vol2/rallsf",
      fstype  => "nfs",
      ensure  => "mounted",
      options => "user,rsize=32768,wsize=32768,hard,intr",
      atboot  => true,
      require => [File["/mnt/rhubarb"], Package["nfs-common"]],
      notify  => Exec["${ids_archive_dir}"],
    }

    # Root can't see it - only dmf
    exec { "${ids_archive_dir}":
      user        => "dmf",
      path        => "/bin",
      command     => "mkdir -p ${ids_archive_dir}",
      refreshonly => true,
    }

    file { ["${ids_main_dir}"]:
      ensure  => directory,
      owner   => dmf,
      group   => dmf,
      require => User["dmf"],
    }

  } else {
    $ids_main_dir = "/home/dmf/ids/main"
    $ids_archive_dir = "/home/dmf/ids/archive"

    file { ["/home/dmf/ids", "${ids_main_dir}", "$ids_archive_dir"]:
      ensure  => directory,
      owner   => dmf,
      group   => dmf,
      require => User["dmf"],
    }

  }

  file { "ids.storage_file.main.properties":
    path    => "/home/dmf/install/config/ids.storage_file.main.properties",
    content => "dir = ${ids_main_dir}",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "ids.storage_file.archive.properties":
    path    => "/home/dmf/install/config/ids.storage_file.archive.properties",
    content => "dir = ${ids_archive_dir}",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "/home/dmf/ingestion":
    ensure => "directory",
    owner  => "dmf",
    group  => "dmf",
  }

  file { "/home/dmf/ingestion/ingest.py":
    ensure => "file",
    source => "puppet:///modules/server_lsf/ingest.py",
    owner  => "dmf",
    group  => "dmf",
    mode   => "0770",
  }

  file { "/home/dmf/ingestion/launcher":
    ensure => "file",
    source => "puppet:///modules/server_lsf/launcher",
    owner  => "dmf",
    group  => "dmf",
    mode   => "0770",
  }

  exec { "run_ingest":
    path     => "/bin",
    cwd      => "/home/dmf/ingestion",
    command  => "su dmf -c ./launcher",
    unless   => "[ -f pidfile ] && ps $(cat pidfile) >> /dev/null",
    provider => "shell",
  }

  file { "ijp.properties":
    path    => "/home/dmf/install/config/ijp",
    source  => "puppet:///modules/server_lsf/config/ijp",
    recurse => true,
    purge   => false,
    owner   => "dmf",
    group   => "dmf",
  }

  file { "/etc/puppet/modules/server/files/python/python-ijp_lsf-1.0.0.tar.gz": source => "/root/downloads/python-ijp_lsf-1.0.0.tar.gz", 
  }

  file { "/usr/local/etc/icat.dump": source => "puppet:///modules/server_lsf/db/icat.dump", }

  file { "/usr/local/sbin/post-db.sh":
    source => "puppet:///modules/server_lsf/db/post-db.sh",
    mode   => "0700",
  }

  exec { "post-db.sh":
    cwd     => "/usr/local/etc/",
    path    => ["/usr/local/sbin", "/usr/bin"],
    require => File["/usr/local/etc/icat.dump", "/usr/local/sbin/post-db.sh"],
    onlyif  => "[ -n $(echo 'select * from FACILITY;' | mysql -u icat -picat icat) ]"
  }

}
