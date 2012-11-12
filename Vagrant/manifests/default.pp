
$how_to_git_user_name = 'triplepoint'
$how_to_git_repo_name = 'web_development_vm_how_to'


$how_to_git_url       = "git://github.com/${how_to_git_user_name}/${how_to_git_repo_name}.git"

package { 'make':
    ensure  => present
}

package { 'git-core':
    ensure  => present
}

exec { "/usr/bin/git clone ${how_to_git_url}":
    cwd     => "/usr/src/",
    creates => "/usr/src/${how_to_git_repo_name}",
    require => Package['git-core']
}

exec { 'make development_server':
    path    => ['/usr/bin', '/bin'],
    cwd     => "/usr/src/${how_to_git_repo_name}",
    require => [
        Exec["/usr/bin/git clone ${how_to_git_url}"],
        Package['make']
    ]
}