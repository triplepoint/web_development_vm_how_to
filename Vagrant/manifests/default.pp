###
# This Puppet manifest clones the PHP server
# configuration files from github and then executes
# the makefile contained in that repository in order
# to build the development server.
#
###

$vagrant_bootstrap_mountpoint = '/vagrant_bootstrap'
$working_directory_path       = '/usr/src/vagrant_build'
$make_logfile                 = "${working_directory_path}/makelog.log"

package { 'make':
    ensure    => present
}

file { $working_directory_path:
    mode      => 0644,
    source    => $vagrant_bootstrap_mountpoint,
    recurse   => true
}

exec { 'make_development_server':
    command   => "make development_server 2>&1 | tee ${make_logfile}",
    path      => ['/usr/bin', '/bin', '/usr/local/bin', '/usr/sbin', '/sbin', '/usr/local/sbin', '/opt/vagrant_ruby/bin'],
    cwd       => $working_directory_path,
    creates   => $make_logfile,
    timeout   => 0,
    require   => [
        File[$working_directory_path],
        Package['make']
    ]
}
