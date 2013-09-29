### Config ###
$project_directory = "/projects"


### Basic Setup ###
# ensure that a 'puppet' user group is present
group { 'puppet': ensure => present }

# Set the bin path
Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }

# Set the default owner, group, and mode of files
File { owner => 0, group => 0, mode => 0644 }

# Make sure apt-get update always runs before apt commands
class {'apt':
    always_apt_update => true,
}

# These packages cause a failure, perhaps to do with the ondrej ppa?
Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

# Add the PPA for php 5.5
apt::key { '4F4EA0AAE5267A6C': }
apt::ppa { 'ppa:ondrej/php5':
    require => Apt::Key['4F4EA0AAE5267A6C']
}


### Install Packages ###
package {[
        # Things other packages depend on
        'build-essential',
        'curl',

        # Things to install because I want them
        'git-core',
        'yui-compressor',
        'ruby-compass',
        'memcached',
        'mysql-server',
        'mysql-client'
   ]:
   ensure => 'present'
}


### UFW (firewall) ###
include ufw
ufw::allow { "allow-ssh-from-all":
    port => 22,
}
ufw::allow { "allow-http-from-all":
    port => 80,
}
ufw::allow { "allow-https-from-all":
    port => 443,
}


### WWW Directory Symlink ###
file { '/var/www':
    ensure => 'link',
    target => $project_directory,
}


### Nginx ###
class { 'nginx': }

nginx::resource::vhost { 'dev.local':
    ensure   => present,
    www_root => '/var/www',
    server_name  => [
        'dev.local',
        'www.dev.local'
    ],
    listen_port  => 80,
    index_files  => [
        'index.html',
        'index.php'
    ],
    try_files    => ['$uri', '$uri/', '/index.php?$args'],
}

 $path_translated = 'PATH_TRANSLATED $document_root$fastcgi_path_info'
 $script_filename = 'SCRIPT_FILENAME $document_root$fastcgi_script_name'

nginx::resource::location { 'dev.local-php':
    ensure              => 'present',
    vhost               => 'dev.local',
    location            => '~ \.php$',
    proxy               => undef,
    try_files           => ['$uri', '$uri/', '/index.php?$args'],
    www_root            => '/var/www/',
    location_cfg_append => {
        'fastcgi_split_path_info' => '^(.+\.php)(/.+)$',
        'fastcgi_param'           => 'PATH_INFO $fastcgi_path_info',
        'fastcgi_param '          => $path_translated,
        'fastcgi_param  '         => $script_filename,
        'fastcgi_pass'            => 'unix:/var/run/php5-fpm.sock',
        'fastcgi_index'           => 'index.php',
        'include'                 => 'fastcgi_params'
    },
    notify              => Class['nginx::service'],
}


### PHP ###


### Composer ###
# class { 'composer':
#     require => Package['php5-fpm', 'curl'],
# }
