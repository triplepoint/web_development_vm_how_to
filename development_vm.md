# BUILD A NEW DEVELOPMENT VIRTUAL MACHINE 
The goal here is to build a development virtual machine that can support PHP web development.  While I'm aiming to keep this generally useful to anyone doing PHP web development, there are places where I install tools or make configuration choices that specifically support my projects.  Be aware that there will need to be some improvization on your part if you want this guide to work for you.

The basic features of this environment are:
- [Minimal Ubuntu 12.04 Server](https://help.ubuntu.com/community/Installation/MinimalCD) as a [VirtualBox](https://www.virtualbox.org/) guest
 - [Windows 7](http://windows.microsoft.com/en-US/windows7/products/home) Host (but don't let that turn you away in disgust, it matters very little)
 - Shared directory between the host and guest for code development
 - Firewall configured with [UFW](https://wiki.ubuntu.com/UncomplicatedFirewall?action=show&redirect=UbuntuFirewall)
- [PHP 5.4.6](http://www.php.net/), compiled from source
 - FastCGI with [PHP-FPM](http://php-fpm.org/), including Unix socket configuration for talking to Nginx
 - [APC](http://php.net/manual/en/book.apc.php), built from [PECL](http://pecl.php.net/)
- [Nginx 1.3.5](http://nginx.org/), compiled from Source, with the [SPDY](http://www.chromium.org/spdy) patch
- [MySQL 5.5](http://dev.mysql.com/doc/refman/5.5/en/), installed from Ubuntu's package repository
- [SASS](http://sass-lang.com/) and [Compass](http://compass-style.org/), for developing CSS
- [YUI Compressor](http://developer.yahoo.com/yui/compressor/), for compressing web assets

## ON THE HOST
### Create the Guest
- Install VirtualBox: https://www.virtualbox.org/wiki/Downloads
- Configure the host-only network:
 - Start up the VirtualBox Manager
 - Go to `File` -> `Preferences...` -> `Network`
 - Ensure the existence of (or create) a Host-Only Network with these properties:
  - Named `VirtualBox Host-Only Ethernet Adapter`
  - IPv4 Address `192.168.56.1`
  - IPv4 Network Mask `255.255.255.0`
  - Disabled DHCP Server
- Download the Ubuntu 12.04 server minimal ISO from https://help.ubuntu.com/community/Installation/MinimalCD/#A64-bit_PC_.28amd64.2C_x86_64.29
- Edit the attached ```create_new_vm.bat``` script and supply reasonable configuration values.  
- From the Windows CLI, run the ```create_new_bm.bat``` batch script with a chosen new Virtual Machine name to create the new virtual machine:
```
create_new_vm.bat SomeNewVMName                   
```

 - This just sets up a new VM, disk, mounts the ubuntu iso and starts the VM
 - Two NICs, one set up for host-only the other one for NAT (see script for details)
 - One shared directory, named 'shared_workspace', from 'E:\Users\jhanson\shared_workspace'
  
- start the virtual machine with:
```
vboxmanage startvm SomeNewVMName
```

- Follow all the onscreen Ubuntu setup, mostly accepting defaults.  When it comes to selecting packages, select only the OpenSSH server.
- Choose an IP address for the guest (I chose `192.168.56.11` below) and set up the Windows hosts file by editing `C:\Windows\System32\drivers\etc\hosts` and adding (note these domains are specific to my configuration):
```
# Development VM
192.168.56.11          jonathan-hanson.local
192.168.56.11          www.jonathan-hanson.local
192.168.56.11          beer.jonathan-hanson.local
192.168.56.11          gas.jonathan-hanson.local
```
If you intend to use IPv6, find the IPv6 zone ID for the VirtualBox Host-Only network by doing the following and reading the 'IDx' column for the 'VirtualBox Host-Only Network':
```
netsh interface ipv6 show interfaces
``` 
Then, (let's say it was 37) in `C:\Windows\System32\drivers\etc\hosts` you can append the zone ID to the virtual host's IPv6 IP address (see below) and add lines like:
```
fe80::38:b%37         ipv6.jonathan-hanson.local
```

- At this point it might be worth while to create a backup of the guest's virtual disk to enable future cloning and rollbacks.  See the VirtualBox Manager for details on how to do this.


## ON THE GUEST
Until the network interfaces are set up correctly, you'll need to do this part from the VirtualBox guest directly (that is, not over SSH).

### Set Up the Network Interfaces
- Noted from `ifconfig` that the `eth0` and `lo` adapters are present but `eth1` isn't.  Did `ifconfig eth1 up` and it came up, but with only an ipv6 address.
- Both adapters were configured for DHCP, but the virtualbox host-only DHCP server is disabled (see above).
- Set up `eth1` with a static IP by adding this to `/etc/network/interfaces`:
```
# The host-only virtualbox interface
auto eth1
iface eth1 inet static
    address 192.168.56.11
    netmask 255.255.255.0
    network 192.168.56.0
    broadcast 192.168.56.255

iface eth1 inet6 static
    address fe80::0038:000B
    netmask 64
```

- Reboot the machine and verify that `ifconfig` now shows `eth1` with the ip address chosen above.  
- At this point you should be able to ssh into the the guest from the host using the IP address chosen above (in my case, `192.168.56.11`).  On subsequent VM startups you should be able to start it headless with:
``` bash
vboxmanage startvm SomeVMName --type=headless
```

### Set Up the Firewall
``` bash
ufw default deny
ufw allow ssh
ufw allow http
ufw allow 443
ufw enable
```


### Add the VirtualBox Shared Mount
``` bash
mkdir /media/sf_shared_workspace
```

- Configure the mount by adding to `/etc/fstab`:
```
# virtualbox shared workspace, owned by www-data:www-data
shared_workspace     /media/sf_shared_workspace vboxsf     defaults,uid=33,gid=33     0     0
```

- Mount the shared disk
``` bash
mount /media/sf_shared_workspace
```


### Install Git
Git is used later by composer.phar, and also to fetch these configuration files.  You'll likely also use it to push and pull project code.
``` bash
apt-get install git
git config --global user.name "Your Name Here"
git config --global user.email "your_email@youremail.com"
```
If you're using Github, it's likely you'll want to set up an SSH key for this machine.  For more information, see:
https://help.github.com/articles/generating-ssh-keys


### Fetch This Documentation:
This documentation includes useful configuration scripts:
``` bash
cd ~
git clone git://github.com/triplepoint/howto_dev_config.git
```

### Install Nginx
- Fetch, make, and install:
``` bash
cd ~
apt-get install libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base
wget http://nginx.org/download/nginx-1.3.5.tar.gz
tar -xvf nginx-1.3.5.tar.gz
cd nginx-1.3.5
# Feel free to skip the wget and patch commands if you don't want to build in SPDY
wget http://nginx.org/patches/spdy/patch.spdy.txt
patch -p0 < patch.spdy.txt
./configure --prefix=/usr --sbin-path=/usr/sbin --pid-path=/var/run/nginx.pid --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --user=www-data --group=www-data --with-http_ssl_module --with-ipv6
make
make install
```

- Install the attached nginx-init script:
``` bash
cp ~/howto_dev_config/etc/init.d/nginx-init /etc/init.d/nginx
chmod 755 /etc/init.d/nginx
update-rc.d nginx defaults
```

- Create the nginx default log directory
``` bash
mkdir /var/log/nginx
```

- Install the generic nginx config files:
``` bash
mkdir /etc/nginx/sites-available
mkdir /etc/nginx/sites-enabled
cp ~/howto_dev_config/etc/nginx/nginx.conf /etc/nginx/
cp ~/howto_dev_config/sites-available/* /etc/nginx/sites-available/*
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
```

- Install the project-specific configuration files.  Note that you'll probably want to copy and edit this file instead of using it directly:
``` bash
cp /etc/nginx/sites-available/example /etc/nginx/sites-available/project_name
ln -s /etc/nginx/sites-available/project_name /etc/nginx/sites-enabled/project_name
```

- start nginx
``` bash
service nginx start
```


### SSL Certificates
For Development, its appropriate to have self-signed SSL certs.  Depending on your project details, you may need more than one cert.
This is more of an example than an exact codeblock to repeat (ref http://adayinthepit.com/2012/03/21/self-signed-ssl-certificate-nginx-and-rightscale/):

``` bash
mkdir ~/certwork
cd ~/certwork
openssl genrsa -des3 -out project_name.key 4096
# Enter a password to protect this key
openssl req -new -key project_name.key -out project_name.csr
# Enter the password from the key above
# Answer the questions appropriately (ex, 'US', 'California', 'San Francisco', 'No Company', 'No Org', '*.local_server_name.local', 'email@email.com', '', '' )
# Note that the common name should be the domain you intend to access (ie, '*.local_server_name.local')
# Note to leave the password blank.
openssl rsa -in project_name.key -out project_name.nginx.key
# Enter the password from the key above
openssl x509 -req -days 3650 -in project_name.csr -signkey project_name.nginx.key -out project_name.nginx.crt
cp project_name.nginx.crt /etc/ssl/certs/
cp project_name.nginx.key /etc/ssl/private/
``` 
Be sure to set the cert and key locations in your project's Nginx config file (see above).  Restart Nginx once the file is edited:
``` bash
sudo service nginx restart
```


### Install PHP
- Fetch, make, and install.  Note that the test command is optional, but good practice:
``` bash
cd ~
apt-get install autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev
wget http://us3.php.net/get/php-5.4.6.tar.bz2/from/us2.php.net/mirror -O php-5.4.6.tar.bz2
tar -xvf php-5.4.6.tar.bz2
cd php-5.4.6
./configure --prefix=/usr --sysconfdir=/etc --with-config-file-path=/etc --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --enable-mbstring --with-mysqli
make
make test
make install
```

- Copy the generated ini file to the config directory:
NOTE - If this is a rebuild and not a fresh install, the better process may be to diff the two files and see if anything important has changed.
``` bash
cp php.ini-production /etc/php.ini
```

- Copy over the PHP-FPM config file: 
``` bash
cp /etc/php-fpm.conf.default /etc/php-fpm.conf
```

 Note that this file has been modified after it was copied:
 - uncommented the pid directive: `pid = run/php-fpm.pid`
 - set the error log location to `/var/log/php-fpm/php-fpm.log`
 - changed the listen location: `listen = /tmp/php.socket`

- Create the PHP-FPM log file:
``` bash
mkdir /var/log/php-fpm
```

- Install the PHP init script:
``` bash
cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
chmod 755 /etc/init.d/php-fpm
update-rc.d php-fpm defaults
```

- Install the APC and HTTP extensions:
``` bash
pecl update-channels
pecl install pecl_http apc-beta (answer with defaults)
```

 NOTE that `apc-beta` was necessary above to get APC version 3.1.11 (in beta right now) which includes fixes for PHP 5.4 compatability.  This may not be necessary down the road, so keep an eye on it.  The production package name is `apc`.

 append to `/etc/php.ini`:
 ```
 extension=http.so
 extension=apc.so
 ```


- start PHP-FPM:
``` bash
service php-fpm start
```


### Set Up the Web Root Symbolic Link
``` bash
ln -s /media/sf_shared_workspace /var/www
```


### MySQL
- Install:
 DON'T DO THIS (because I'm not building from scratch just yet):
``` bash
apt-get install cmake
wget http://dev.mysql.com/get/Downloads/MySQL-5.5/mysql-5.5.25a.tar.gz/from/http://cdn.mysql.com/ -O mysql-5.5.25a.tar.gz
tar -xvf mysql-5.5.25a.tar.gz
cd mysql-5.5.25a
```

 Instead do this: (because screw it, I'm cheating on this one and using `apt-get`.  Building MySQL from source looks like a pain in the ass with no gain):
 ``` bash
 apt-get install mysql-server-5.5  
 ```


### Install Compass/Sass
``` bash
apt-get install ruby1.9.3
gem update
gem install compass
ln -s /usr/local/bin/compass /usr/bin/compass
```


### Install YUI Compressor
- Install java runtime (required for yui compressor):
``` bash
apt-get install default-jre
```

- Fetch and install the `yui-compressor` jar file
``` bash
cd ~
apt-get install unzip
wget http://yui.zenfs.com/releases/yuicompressor/yuicompressor-2.4.7.zip
unzip yuicompressor-2.4.7.zip
mkdir /usr/share/yui-compressor
cp yuicompressor-2.4.7/build/yuicompressor-2.4.7.jar /usr/share/yui-compressor/yui-compressor.jar
```


# UPDATING
Periodically it'll be necessary to upgrade this machine without rebuilding it.  Here's how:
- Apt Repository update (covers MySQL): 
``` bash
apt-get update; apt-get dist-upgrade;
```
- PHP -- make clean and recompile as during the install above
- PECL and PEAR
``` bash
pecl update-channels
pecl upgrade
pear update-channels
pear upgrade
```
- Nginx -- make clean and recompile as during the install above
- Ruby Gem update for Compass and SASS:
``` bash 
gem update
```  
- YUI-Compressor - redownload and overwrite the jar file, as during the install above

Once all upgrades are complete, the various services will need to be restarted
``` bash
service mysql restart
service php-fpm restart
service nginx restart
```

# TODO
- mysql config
- phpmyadmin
- the eth1 interface doesn't have a static IPV6 address.  Need to research how to do that.
- look into an ssl cert for the default nginx config (not just per project)
- on server errors, nginx just throws ugly 500 response
- scriptify everything
- project code git pull (this isn't actually necessary for VM dev machines, but I should document it for building in production)
- Come up with the production server variant of all this (should be similar)


# NOTES
- http://wiki.nginx.org/Configuration
- http://www.howtoforge.com/installing-php-5.3-nginx-and-php-fpm-on-ubuntu-debian
