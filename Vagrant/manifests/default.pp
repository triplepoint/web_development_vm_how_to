###
# This Puppet manifest clones the PHP server
# configuration files from github and then executes
# the makefile contained in that repository in order
# to build the development server.
#
###

$how_to_github_user_name  = 'triplepoint'
$how_to_github_repo_name  = 'web_development_vm_how_to'

$how_to_git_url           = "git://github.com/${how_to_github_user_name}/${how_to_github_repo_name}.git"

$which_makefile_target    = 'development_server'

$make_logfile             = "/usr/src/${how_to_github_repo_name}/makelog.log"



package { 'make':
    ensure    => present
}

package { 'git-core':
    ensure    => present
}

file { '/usr/src':
    ensure    => directory,
    mode      => 0644
}

exec { 'git_clone':
    command   => "/usr/bin/git clone ${how_to_git_url}",
    cwd       => '/usr/src/',
    creates   => "/usr/src/${how_to_github_repo_name}",
    require   => [
        File['/usr/src'],
        Package['git-core']
    ]
}

exec { 'make_server':
    command   => "make ${which_makefile_target} 2>&1 | tee ${make_logfile}",
    path      => ['/usr/bin', '/bin', '/usr/local/bin', '/usr/sbin', '/sbin', '/usr/local/sbin', '/opt/vagrant_ruby/bin'],
    cwd       => "/usr/src/${how_to_github_repo_name}",
    creates   => $make_logfile,
    timeout   => 0,
    require   => [
        Exec['git_clone'],
        Package['make']
    ]
}
