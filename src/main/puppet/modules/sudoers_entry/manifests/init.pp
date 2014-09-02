#
# sudoers
#
define sudoers_entry($user = $title) {
  file { "/etc/sudoers.d/${name}":
    source => "puppet:///modules/sudoers_entry/${name}",
    mode => "0440",
    owner => "root",
    group => "root",
  }
}
