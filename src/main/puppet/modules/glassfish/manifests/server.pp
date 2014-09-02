#
# glassfish
#
class glassfish::server {
  @@file { "/usr/local/etc/glassfish.services":
    content => "
icaturl https://${fqdn}:8181
idsurl https://${fqdn}:8181
ijpurl https://${fqdn}:8181",
    ensure  => present,
  }

  $local_url = "https://${fqdn}:8181"

  file { "authn_db-distro.zip":
    path    => "/home/dmf/install/distro/authn_db-distro.zip",
    source  => "puppet:///modules/glassfish/distros/authn_db-1.1.1-distro.zip",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "authn_db-setup.properties":
    path    => "/home/dmf/install/config/authn_db-setup.properties",
    source  => "puppet:///modules/glassfish/config/authn_db-setup.properties",
    owner   => dmf,
    group   => dmf,
    mode    => 0600,
    require => User["dmf"],
  }

  file { "authn_db.properties":
    path    => "/home/dmf/install/config/authn_db.properties",
    source  => "puppet:///modules/glassfish/config/authn_db.properties",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  exec { "authn_db":
    command     => "${base::deploy} dmf authn_db authn_db-distro.zip authn_db-setup.properties authn_db.properties",
    subscribe   => File["authn_db-distro.zip", "authn_db-setup.properties", "authn_db.properties"],
    refreshonly => true,
  }

  file { "authn_ldap-distro.zip":
    path    => "/home/dmf/install/distro/authn_ldap-distro.zip",
    source  => "puppet:///modules/glassfish/distros/authn_ldap-1.1.0-distro.zip",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "authn_ldap-setup.properties":
    path    => "/home/dmf/install/config/authn_ldap-setup.properties",
    source  => "puppet:///modules/glassfish/config/authn_ldap-setup.properties",
    owner   => dmf,
    group   => dmf,
    mode    => 0600,
    require => User["dmf"],
  }

  file { "authn_ldap.properties":
    path    => "/home/dmf/install/config/authn_ldap.properties",
    source  => "puppet:///modules/glassfish/config/authn_ldap.properties",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  exec { "authn_ldap":
    command     => "${base::deploy} dmf authn_ldap authn_ldap-distro.zip authn_ldap-setup.properties authn_ldap.properties",
    subscribe   => File["authn_ldap-distro.zip", "authn_ldap-setup.properties", "authn_ldap.properties"],
    refreshonly => true,
  }

  file { "icat-distro.zip":
    path    => "/home/dmf/install/distro/icat-distro.zip",
    source  => "puppet:///modules/glassfish/distros/icat.ear-4.3.2-distro.zip",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "icat-setup.properties":
    path    => "/home/dmf/install/config/icat-setup.properties",
    source  => "puppet:///modules/glassfish/config/icat-setup.properties",
    owner   => dmf,
    group   => dmf,
    mode    => 0600,
    require => User["dmf"],
  }

  file { "icat.properties":
    path    => "/home/dmf/install/config/icat.properties",
    source  => "puppet:///modules/glassfish/config/icat.properties",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  exec { "icat":
    command     => "${base::deploy} dmf icat icat-distro.zip icat-setup.properties icat.properties",
    subscribe   => [File["icat-distro.zip", "icat-setup.properties", "icat.properties"], Exec["authn_db", "authn_ldap"]],
    refreshonly => true,
  }

  file { "ids.storage_file-distro.zip":
    path    => "/home/dmf/install/distro/ids.storage_file-distro.zip",
    source  => "puppet:///modules/glassfish/distros/ids.storage_file-1.0.0-distro.zip",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "ids.storage_file-setup.properties":
    path    => "/home/dmf/install/config/ids.storage_file-setup.properties",
    source  => "puppet:///modules/glassfish/config/ids.storage_file-setup.properties",
    owner   => dmf,
    group   => dmf,
    mode    => 0600,
    require => User["dmf"],
  }

  exec { "ids.storage_file":
    command     => "${base::deploy} dmf ids.storage_file ids.storage_file-distro.zip ids.storage_file-setup.properties ids.storage_file.*.properties",
    subscribe   => File["ids.storage_file-distro.zip", "ids.storage_file-setup.properties", "ids.storage_file.main.properties", "ids.storage_file.archive.properties"
      ],
    refreshonly => true,
  }

  file { "ids.server-distro.zip":
    path    => "/home/dmf/install/distro/ids.server-distro.zip",
    source  => "puppet:///modules/glassfish/distros/ids.server-1.0.1-distro.zip",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "ids-setup.properties":
    path    => "/home/dmf/install/config/ids-setup.properties",
    source  => "puppet:///modules/glassfish/config/ids-setup.properties",
    owner   => dmf,
    group   => dmf,
    mode    => 0600,
    require => User["dmf"],
  }

  file { [
    "/home/dmf/glassfish4/glassfish/domains/domain1/data",
    "/home/dmf/glassfish4/glassfish/domains/domain1/data/ids",
    "/home/dmf/glassfish4/glassfish/domains/domain1/data/ids/cache"]:
    ensure  => directory,
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "ids.properties":
    path    => "/home/dmf/install/config/ids.properties",
    content => "
icat.url = https://${fqdn}:8181
plugin.main.class = org.icatproject.ids.storage.MainFileStorage
plugin.main.properties = ids.storage_file.main.properties
cache.dir = ../data/ids/cache
preparedCacheSize1024bytes = 1000000
preparedCount = 100
processQueueIntervalSeconds = 5
rootUserNames = root
reader = db username reader password reader
sizeCheckIntervalSeconds = 60
plugin.archive.class = org.icatproject.ids.storage.ArchiveFileStorage
plugin.archive.properties = ids.storage_file.archive.properties
datasetCacheSize1024bytes = 1000000
writeDelaySeconds = 60
tolerateWrongCompression =
",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  exec { "ids.server":
    command     => "${base::deploy} dmf ids.server ids.server-distro.zip ids-setup.properties ids.properties",
    subscribe   => File["ids.server-distro.zip", "ids-setup.properties", "ids.properties"],
    refreshonly => true,
    require     => Exec["ids.storage_file", "icat"],
  }

  file { "ijp-distro.zip":
    path    => "/home/dmf/install/distro/ijp-distro.zip",
    source  => "puppet:///modules/glassfish/distros/ijp.server-2.0.1-SNAPSHOT-distro.zip",
    owner   => dmf,
    group   => dmf,
    require => User["dmf"],
  }

  file { "ijp-setup.properties":
    path    => "/home/dmf/install/config/ijp-setup.properties",
    source  => "puppet:///modules/glassfish/config/ijp-setup.properties",
    owner   => dmf,
    group   => dmf,
    mode    => 0600,
    require => User["dmf"],
  }

  file { "ijp.ijp.properties":
    path    => "/home/dmf/install/config/ijp/ijp.properties",
    content => "
icat.url = https://${fqdn}:8181
ids.url = https://${fqdn}:8181
gangliaHost = ${fqdn}
pbsnodes = pbsnodes
qsig = qsig
qstat = qstat
qsub = qsub
prepareaccount = /home/dmf/bin/prepareaccount
passwordDurationSeconds = 120
poolPrefix = pool
reader = db username anon password anon
authn.list ldap db
authn.ldap.friendly Federal Id
authn.ldap.list username password
authn.ldap.password.visible false
authn.db.friendly Local ICAT database
authn.db.list username password
authn.db.password.visible false
",
    require => File["ijp.properties"],
  }

  exec { "ijp":
    command     => "${base::deploy} dmf ijp.server ijp-distro.zip ijp-setup.properties ijp",
    subscribe   => File["ijp-distro.zip", "ijp-setup.properties", "ijp.properties", "ijp.ijp.properties"],
    refreshonly => true,
    require     => Exec["authn_db", "authn_ldap"],
  }

}
