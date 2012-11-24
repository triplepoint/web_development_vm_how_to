###
# This Puppet manifest clones the PHP server
# configuration files from github and then executes
# the makefile contained in that repository in order
# to build the development server.
#
###

$how_to_git_user_name = 'triplepoint'
$how_to_git_repo_name = 'web_development_vm_how_to'

$how_to_git_url       = "git://github.com/${how_to_git_user_name}/${how_to_git_repo_name}.git"

package { 'make':
    ensure    => present
}

package { 'git-core':
    ensure    => present
}

exec { 'git_clone':
    command   => "/usr/bin/git clone ${how_to_git_url}",
    cwd       => '/usr/src/',
    creates   => "/usr/src/${how_to_git_repo_name}",
    require   => Package['git-core']
}

exec { 'make_server':
    command   => 'make development_server >> makelog.log',
    path      => ['/usr/bin', '/bin', '/usr/local/bin', '/usr/sbin', '/sbin', '/usr/local/sbin'],
    cwd       => "/usr/src/${how_to_git_repo_name}",
    timeout   => 0,
    require   => [
        Exec['git_clone'],
        Package['make']
    ]
}
