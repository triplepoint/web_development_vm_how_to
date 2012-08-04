# BUILD A NEW DEVELOPMENT VM #

## ON THE HOST ##
### Create the guest ###
- Install VirtualBox: https://www.virtualbox.org/wiki/Downloads
- Configure the host-only network (TODO flesh out these notes)
- from Windows CLI, run this batch script to create the new virtual machine:
```
create_new_vm.bat SomeNewVMName                   
```

 - ## This just sets up a new VM, disk, mounts the ubuntu iso and starts the VM
 - ## Two NICs, one set up for host-only the other one for NAT (see script for details)
 - ## One shared directory, named 'shared_workspace', from E:\Users\jhanson\shared_worksace
 - ## https://help.ubuntu.com/community/Installation/MinimalCD/#A64-bit_PC_.28amd64.2C_x86_64.29
  
- Follow all the onscreen setup, mostly accepting defaults.  Install the openssh server though (that was the only package i selected).
- set up the windows hosts file, edit c:\Windows\System32\drivers\etc\hosts and add:
```
# Development VM
192.168.56.11          jonathan-hanson.local
192.168.56.11          www.jonathan-hanson.local
192.168.56.11          beer.jonathan-hanson.local
192.168.56.11          gas.jonathan-hanson.local
```

- ssh into the VM at the IP address you chose and with the credentials you set up in the Ubuntu configuration.

## ON THE GUEST ##
### Interfaces ###
Fresh install of ubuntu from mini.iso (ubuntu server 12.04 mini install)
 - Only package installed was openssh server
- Made a backup copy of the virtual disk right after logging in once (fresh_ubuntu_1204_server.vdi)
- Noted from ifconfig that eth0 and lo are present as network adaptors, but eth1 isn't.  Did `ifconfig eth1 up` and it came up, but with only an ipv6 address. Weird.
-  Both adapters were configured for DHCP, which is turned off in my virtual box host config (see /etc/network/interfaces).
-  In order to set up a static IP, added to /etc/network/interfaces:
# The host-only virtualbox interface
auto eth1
iface eth1 inet static
address 192.168.56.11
netmask 255.255.255.0
network 192.168.56.0
broadcast 192.168.56.255

- Rebooted and the machine comes up as expected (could probably also do `sudo service networking restart`, but didn't test)


### Set up firewall ###
sudo ufw default deny
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow 443
sudo ufw enable


### Add virtualbox shared mounts ###
sudo mkdir /media/sf_shared_workspace
add to /etc/fstab:
# virtualbox shared workspace, owned by www-data:www-data
shared_workspace     /media/sf_shared_workspace vboxsf     defaults,uid=33,gid=33     0     0

sudo mount /media/sf_shared_workspace


### install nginx ###
sudo apt-get install libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base
wget http://nginx.org/download/nginx-1.2.2.tar.gz
tar -xvf nginx-1.2.2.tar.gz
cd nginx-1.2.2
./configure --prefix=/usr --sbin-path=/usr/sbin --pid-path=/var/run/nginx.pid --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --user=www-data --group=www-data --with-http_ssl_module
make
sudo make install

cp nginx /etc/init.d/                           // TODO I need to actually source this with wget from somewhere.  Note this file has been edited in place.
sudo chmod 755 /etc/init.d/nginx
sudo update-rc.d nginx defaults

sudo mkdir /var/log/nginx

sudo mkdir /etc/nginx/sites-available
sudo mkdir /etc/nginx/sites-enabled
cp nginx.conf /etc/nginx/                              // TODO I need to actually source this with wget from somewhere.  Note this file has been edited in place.
cp sites-available/* /etc/nginx/sites-available/*   // TODO I need to actually source this with wget from somewhere.  Note this file has been edited in place.
ln -s /etc/nginx/sites-available/catchall /etc/nginx/sites-enabled/catchall
ln -s /etc/nginx/sites-available/groundhog /etc/nginx/sites-enabled/groundhog

-- start nginx
sudo service nginx start


### install php ###
sudo apt-get install autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev
wget http://us3.php.net/get/php-5.4.5.tar.bz2/from/us2.php.net/mirror -O php-5.4.5.tar.bz2
tar -xvf php-5.4.5.tar.bz2
cd php-5.4.5
./configure --prefix=/usr --sysconfdir=/etc --with-config-file-path=/etc --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --enable-mbstring --with-mysqli
make
sudo make install

sudo cp php.ini-production /etc/php.ini

sudo cp /etc/php-fpm.conf.default /etc/php-fpm.conf      ### NOTE: Modified
   -- uncommented the pid directive: pid = run/php-fpm.pid
   -- set the error log location to /var/log/php-fpm/php-fpm.log
   -- changed the listen location: listen = /tmp/php.socket
sudo mkdir /var/log/php-fpm

sudo cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
sudo chmod 755 /etc/init.d/php-fpm
sudo update-rc.d php-fpm defaults

sudo pecl update-channels
sudo pecl install pecl_http apc-beta (answer with defaults)
# note that apc-beta was necessary to get  apc 3.1.11 (in beta right now) which includes fixes for php 5.4 compatability

append to /etc/php.ini:
extension=http.so
extension=apc.so


-- set up web root
sudo mkdir /var/www

-- start php-fpm
sudo service php-fpm start


### MYSQL ###
##sudo apt-get install cmake
##wget http://dev.mysql.com/get/Downloads/MySQL-5.5/mysql-5.5.25a.tar.gz/from/http://cdn.mysql.com/ -O mysql-5.5.25a.tar.gz
##tar -xvf mysql-5.5.25a.tar.gz
##cd mysql-5.5.25a
sudo apt-get install mysql-server-5.5    ## screw it, I'm cheating on this one and using apt-get.  Building from source looks like a pain in the ass with no gain.


### set up development code symbolic link ###
sudo ln -s /media/sf_shared_workspace /var/www


### Install Compass/Sass ###
sudo apt-get install ruby1.9.3
sudo gem update
sudo gem install compass
sudo ln -s /usr/local/bin/compass /usr/bin/compass


### Install YUI Compressor ###
### Install java runtime (for yui compressor) ###
sudo apt-get install default-jre

sudo apt-get install unzip
wget http://yui.zenfs.com/releases/yuicompressor/yuicompressor-2.4.7.zip
unzip yuicompressor-2.4.7.zip
sudo mkdir /usr/share/yui-compressor
sudo cp yuicompressor-2.4.7/build/yuicompressor-2.4.7.jar /usr/share/yui-compressor/yui-compressor.jar


### Install Git (used by composer.phar) ###
sudo apt-get install git


# UPDATING #
Periodically it'll be necessary to upgrade this machine without rebuilding it.  Here's how:
-- sudo apt-get update; sudo apt-get dist-upgrade;
-- php - make clean and recompile as above
-- nginx -- make clean and recompile as above
-- ## Mysql is handled by apt-get
-- sudo gem update;  ### Handles compass
-- YUI-compressor - redownload and overwrite the jar file, as above


# TODO #
- mysql config
- SSL cert
- IPv6?
- on server errors, nginx just throws ugly 500 response
- scriptify everything
- Come up with the production server variant of all this (should be similar)
- groundhog git pull (this isn't actually necessary for VM dev machines, but i should research it for building in production)


# NOTES #
- http://www.howtoforge.com/installing-php-5.3-nginx-and-php-fpm-on-ubuntu-debian











