# How To Build a Web Server Virtual Machine
## Introduction
The goal here is to build a virtual machine that can act as both a local development environment and a production server.  While I'm aiming to keep this generally useful to anyone doing PHP web development, there are places where I install tools or make configuration choices that specifically support my projects.  Be aware that there will need to be some improvization on your part if you want this guide to work for you.

The basic features of this environment are:

- [Minimal Ubuntu 12.04 "Precise" Server][ubuntu_minimal] as a [VirtualBox] guest
    - Shared directory between the host and guest for code development
    - Firewall configured with [UFW]
- [PHP 5.5 stable][php], compiled from source
    - FastCGI with [PHP-FPM], including Unix socket configuration for talking to [Nginx]
    - [XDebug], built from source via [PECL]
- [Nginx 1.4 stable][nginx], compiled from source
- [MySQL 5.6][mysql], compiled from source
- [SASS] and [Compass], for developing CSS
- [YUI Compressor][yui_comp], for compressing web assets

## Automated Build
The instructions in this guide should be very close to the automated [Vagrant] build provided along with this document.  It should be possible for you to build this environment automatically with:
- Install VirtualBox from their [download page][vbox_dl]
- Install [Vagrant] v1.1+
- Check out this guide repository somewhere convenient

    ``` bash
    cd \someplace\convenient
    git clone git://github.com/triplepoint/web_development_vm_how_to.git how_to
    ```
- Edit the Vagrant configuration, if necessary
  - In `Vagrant\Vagrantfile`, the `/projects` share point is the project directory to share between your host and the virtual machine.  Edit it appropriately to point to your projects.
  - In `Vagrant\Vagrantfile`, the ` web_server_config.vm.network` configuration sets the IP address of the virtual machine.  If this conflicts for you, you'll need to change it.
- Build the machine

    Vagrant will use the `makefile` packaged along with this guide to build the environment automatically.

    ``` bash
    cd \someplace\convenient\how_to\Vagrant
    vagrant up
    ```
- Finally, you can get the SSH credentials from Vagrant and use them with whatever SSH client you want

    ``` bash
    vagrant ssh
    ```

The rest of this guide documents the manual way to build this environment.  While there are likely a few differences between the resulting machines, hopefully they're simple cosmetic differences.

## Manual Build
### On the Host
#### Create the Guest
- Install VirtualBox from their [download page][vbox_dl]
- Configure the host-only network
    - Start up the VirtualBox Manager
    - Go to `File` -> `Preferences...` -> `Network`
    - Ensure the existence of (or create) a Host-Only Network with these properties
        - Named `VirtualBox Host-Only Ethernet Adapter`
        - IPv4 Address `192.168.56.1`
        - IPv4 Network Mask `255.255.255.0`
        - Disabled DHCP Server
- Download the [Ubuntu 12.04 server minimal ISO][ubuntu_minimal]
- From the host's command line, create and configure the new virtual machine (be careful to modify the commands appropriately for suitable names and file paths):

    ``` dos
    # Create the new disk - make sure the filename path and VM name are modified appropriately
    VboxManage createhd --filename "E:\Users\username\VirtualBox VMs\new_vm_name\new_vm_name.vdi" --size 10240 --format VDI --variant Standard

    # Create the new vm - make sure the VM name is modified appropriately
    VboxManage createvm --name "new_vm_name" --ostype Ubuntu_64 --register
    VboxManage modifyvm "new_vm_name" --memory 2048 --vram 12 --acpi on --ioapic on --cpus 1 --rtcuseutc on --boot1 dvd --boot2 disk --boot3 none --boot4 none --audio none
    VboxManage modifyvm "new_vm_name" --nic1 nat --nictype1 82540EM
    VboxManage modifyvm "new_vm_name" --nic2 hostonly --nictype2 82540EM --hostonlyadapter2 "VirtualBox Host-Only Ethernet Adapter"

    # Create the HD controller and attach the disk - make sure the medium path and VM name are modified appropriately
    VBoxManage storagectl "new_vm_name" --name "SATA Controller" --add sata --controller IntelAHCI
    VBoxManage storageattach "new_vm_name" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "E:\Users\username\VirtualBox VMs\new_vm_name\new_vm_name.vdi"

    # Create the DVD drive controller and attach the CD ROM ISO - make sure the medium path is where you downloaded the ISO above, and that the VM name is modified appropriately
    VBoxManage storagectl "new_vm_name" --name "IDE Controller" --add ide
    VBoxManage storageattach "new_vm_name" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "E:\Users\username\Downloads\mini.iso"

    # Shared folders - verify the VM name, and pick an appropriate hostpath directory to share between the host and guest
    VBoxManage sharedfolder add "new_vm_name" --name "shared_workspace" --hostpath "E:\Users\username\workspace"
    ```
- start the virtual machine with:

    ``` dos
    VBoxManage startvm new_vm_name
    ```
- Follow all the onscreen Ubuntu setup, accepting defaults.  When it comes to selecting packages, select only the `OpenSSH server`
- Choose an IP address for the guest (I chose `192.168.56.11` below) and set up the Windows hosts file by editing `C:\Windows\System32\drivers\etc\hosts` and adding (note these domains are specific to my configuration, yours are likely different):

    ```
    # Development VM
    192.168.56.11          jonathan-hanson.local
    192.168.56.11          www.jonathan-hanson.local
    ```
    If you intend to use IPv6, find the IPv6 zone ID for the VirtualBox Host-Only network by doing the following and reading the 'IDx' column for the 'VirtualBox Host-Only Network':

    ``` dos
    netsh interface ipv6 show interfaces
    ```
    Then, (let's say it was 37) in `C:\Windows\System32\drivers\etc\hosts` you can append the zone ID to the virtual host's IPv6 IP address (see below) and add lines like:

    ```
    fe80::38:b%37         ipv6.jonathan-hanson.local
    ```
- At this point it might be worth while to create a backup of the guest's virtual disk to enable future cloning and rollbacks.  See the [VirtualBox Media Manager][vbox_clone] for details on how to do this.


### On the Guest
Until the network interfaces are set up correctly, you'll need to do this part from the VirtualBox guest directly (that is, not over SSH).


#### Set Up the Network Interfaces
- I noted from `ifconfig` that the `eth0` and `lo` adapters are present at this point, but `eth1` isn't.  I did `ifconfig eth1 up` and it came up, but with only an ipv6 address, which is incorrect.

    It turns out both adapters were configured for DHCP, but the Virtualbox host-only DHCP server is disabled (see above).

    Set up `eth1` with a static IP by adding this to `/etc/network/interfaces`:

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
- Reboot the machine and verify that `ifconfig` now shows `eth1` with the ip address chosen above
- At this point you should be able to ssh into the the guest from the host using the IP address chosen above (in my case, `192.168.56.11`).  On subsequent VM startups you should be able to start it headless with:

    ``` bash
    vboxmanage startvm SomeVMName --type=headless
    ```

#### Update the Software Packages
Later, when we install tools and dependencies which we've chosen not to build from source, this will ensure we have the latest knowledge of available packages.

``` bash
apt-get update;
```

#### Set Up the Firewall
This part is quick and easy.

``` bash
ufw default deny
ufw allow ssh
ufw allow http
ufw allow 443
ufw enable
```

#### Add the VirtualBox Shared Mount
We'll be editing code on the host machine and sharing it to the guest VM with a shared mount.

- Create the directory which will be the mount point for the share

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
- Set Up the Web Root Symbolic Link

    ``` bash
    ln -s /media/sf_shared_workspace /var/www
    ```


#### Install Git
Git is used later by composer.phar, and also to fetch these configuration files.

``` bash
apt-get install git-core
git config --global user.name "Your Name Here"
git config --global user.email "your_email@youremail.com"
```
If you're using GitHub, it's likely you'll want to set up an SSH key for this machine.  For more information, see [GitHub's documentation on SSH keys][github_ssh].


#### Fetch This Documentation
This documentation includes useful configuration scripts, so we'll fetch it into the VM for easy access:

``` bash
cd /usr/src/
git clone git://github.com/triplepoint/web_development_vm_how_to.git
```


#### Install Nginx
- Fetch, make, and install:

    ``` bash
    cd /usr/src/
    apt-get install libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base

    wget http://nginx.org/download/nginx-1.4.2.tar.gz
    tar -xvf nginx-1.4.2.tar.gz
    cd nginx-1.4.2

    ./configure --prefix=/usr --sbin-path=/usr/sbin --pid-path=/var/run/nginx.pid --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --user=www-data --group=www-data --with-http_ssl_module --with-http_spdy_module --with-ipv6
    make
    make install
    ```
- Install the attached nginx-init script:

    ``` bash
    cp /usr/src/web_development_vm_how_to/etc/init.d/nginx-init /etc/init.d/nginx
    chmod 755 /etc/init.d/nginx
    update-rc.d nginx defaults
    ```
- Create the Nginx default log directory

    ``` bash
    mkdir /var/log/nginx
    ```
- Install the generic Nginx config files:

    ``` bash
    mkdir /etc/nginx/sites-available
    mkdir /etc/nginx/sites-enabled
    cp /usr/src/web_development_vm_how_to/etc/nginx/nginx.conf /etc/nginx/
    cp /usr/src/web_development_vm_how_to/etc/nginx/sites-available/* /etc/nginx/sites-available
    ```
- start Nginx

    ``` bash
    service nginx start
    ```


#### Install PHP
- Fetch, make, and install.  Note that the test command is optional, but good practice:

    ``` bash
    cd /usr/src/
    apt-get install autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev
    wget http://us3.php.net/get/php-5.5.2.tar.bz2/from/us2.php.net/mirror -O php-5.5.2.tar.bz2
    tar -xvf php-5.5.2.tar.bz2
    cd php-5.5.2
    ./configure --prefix=/usr --sysconfdir=/etc --with-config-file-path=/etc --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --enable-opcache --enable-mbstring --enable-mbregex --with-mysqli --with-openssl --with-curl --with-zlib
    make
    make test
    make install
    ```
- Copy the provided php.ini file to the config directory

    ``` bash
    cp /usr/src/web_development_vm_how_to/etc/php.ini /etc/php.ini
    ```
    *NOTE* - This provided php.ini file is a stripped down custom version.  The PHP-provided default versions are present in the
    php source as `php.ini-production` and `php.ini-development`.   Feel free to copy one of those instead, but note that the date.timezone
    will need to be set to avoid warnings.

- Install the PHP init script

    ``` bash
    cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    chmod 755 /etc/init.d/php-fpm
    update-rc.d php-fpm defaults
    ```
- Copy over the PHP-FPM config file:

    ``` bash
    cp /etc/php-fpm.conf.default /etc/php-fpm.conf
    ```

    *NOTE* - this file needs to be modified after it's copied:
    - uncomment the pid directive: `pid = run/php-fpm.pid`
    - uncomment and set the `error_log` location to `/var/log/php-fpm/php-fpm.log`: `error_log = /var/log/php-fpm/php-fpm.log`
    - changed the `listen` location: `listen = /tmp/php.socket`
- Create the PHP-FPM and PHP log directories:

    ``` bash
    mkdir /var/log/php-fpm
    mkdir /var/log/php
    ```
- Install the PECL extensions: HTTP, XDebug

    ``` bash
    pecl update-channels
    # when prompted, answer with defaults
    pecl install pecl_http xdebug
    ```
    append to `/etc/php.ini` (skip this step if you're using the custom php.ini provided above):

    ```
    extension = http.so
    zend_extension = "/usr/lib/php/extensions/no-debug-non-zts-20121212/xdebug.so"
    ```
- start PHP-FPM

    ``` bash
    service php-fpm start
    ```


#### MySQL
- Add the MySQL User

    ``` bash
    groupadd mysql
    useradd -c "MySQL Server" -r -g mysql mysql
    ```
- Install

    ``` bash
    apt-get install build-essential cmake libaio-dev libncurses5-dev
    wget http://cdn.mysql.com/Downloads/MySQL-5.6/mysql-5.6.12.tar.gz -O mysql-5.6.12.tar.gz
    tar -xvf mysql-5.6.12.tar.gz
    cd mysql-5.6.12

    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr/share/mysql -DSYSCONFDIR=/etc ..
    make
    make install
    ```
- Set up the system tables

    ``` bash
    chown -R mysql:mysql /usr/share/mysql
    cd /usr/share/mysql/ && scripts/mysql_install_db --user=mysql
    chown -R root /usr/share/mysql
    chown -R mysql /usr/share/mysql/data
    ```
- Set up the MySQL config file

    ``` bash
    cp /usr/share/mysql/support-files/my-default.cnf /etc/my.cnf
    ```
- Set up the MySQL init script

    ``` bash
    cp /usr/share/mysql/support-files/mysql.server /etc/init.d/mysqld
    chmod 755 /etc/init.d/mysqld
    update-rc.d mysqld defaults
    ```
- Start MySQL

    ``` bash
    service mysqld start
    ```


#### Install YUI Compressor
We could fetch this from GitHub and build it manually, but I don't think it's worth the effort.  The version in the repository works fine:

``` bash
apt-get install yui-compressor
```


#### Install Compass/Sass
We could install Ruby and use Gems ot install compass, but honestly the version in the package repo is just as good.

``` bash
apt-get install ruby-compass
```


## Updating
Periodically it may be necessary to upgrade this machine without rebuilding it.  Here's how:
- Apt Repository update (covers MySQL, compass, and yui-compressor):

    ``` bash
    apt-get update; apt-get upgrade;
    ```
- PHP - `make clean` and recompile as during the install above
- PECL and PEAR

    ``` bash
    pecl update-channels
    pecl upgrade
    pear update-channels
    pear upgrade
    ```
- Nginx - `make clean` and recompile as during the install above

Once all upgrades are complete, the various services will need to be restarted

``` bash
service mysql restart
service php-fpm restart
service nginx restart
```


# Setting up projects
This guide is primarily aimed at setting up a generic server, and project-specific configuration is probably too specific to get into here.
However, here's a few bits and pieces that may be useful in setting up a project.

## Example makefile
There's a project makefile example attached to this documenation at `project.makefile.example`.  It would be appropriate to copy this file to something like `install\makefile` in your project code and edit it to make it appropriate for your project.  After that you can run:

``` bash
make install_dev
```
What follows below is more or less the manual version of what the example makefile above would do.


## Nginx config file
There are example nginx config files available with this documentation in `etc/nginx/sites-available`.  It would be appropriate to copy one of these into /etc/nginx/sites-available with your project's name, and then edit it for your specific project.  AFter that you could symlink it into `sites-enabled` like so:
``` bash
cp etc/nginx/sites-available/example /etc/nginx/sites-available/my_project_name
### edit /etc/nginx/sites-available/my_project_name to make it suitable for your project
ln -s /etc/nginx/sites-available/my_project_name /etc/nginx/sites-enabled/my_project_name
```

## SSL Certificates
For Development, its appropriate to have self-signed SSL certs.  Depending on your project details, you may need more than one cert.
This is more of an example than an exact codeblock to be repeated. See [adayinthepit.com's article on self-signed SSL certificates][adayinthepit_ssl_certs]:

- Generate the certificate files

    ``` bash
    mkdir /usr/src/certwork
    cd /usr/src/certwork
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
- Be sure to set the cert and key locations in your project's Nginx config file (see above).

## Restart Nginx
Remember that any time you modify nginx config you need to restart it:
``` bash
service nginx restart
```


# Todo
- mysql config
- PHPMyAdmin (this should probably live on a separate VM)
- the `eth1` interface doesn't have a static IPV6 address.  Need to research how to do that.
- on server errors, Nginx just throws ugly 500 response


# Notes and References
- [Nginx configuration documentation][nginx_config_doc]
- [How-to Forge article on PHP-FPM on Nginx][how_to_forge_phpfpm_nginx]


[ubuntu_minimal]: https://help.ubuntu.com/community/Installation/MinimalCD/#A64-bit_PC_.28amd64.2C_x86_64.29 "Ubuntu Minimal CD Download Page"
[Virtualbox]: https://www.virtualbox.org/ "Virtualbox"
[win7]: http://windows.microsoft.com/en-US/windows7/products/home "Windows 7"
[UFW]: https://wiki.ubuntu.com/UncomplicatedFirewall?action=show&redirect=UbuntuFirewall "Uncomplicated Firewall"
[php]: http://www.php.net/ "PHP"
[PHP-FPM]: http://php-fpm.org/ "PHP FastCGI Process Manager"
[XDebug]: http://xdebug.org/ "XDebug Extension for PHP"
[PECL]: http://pecl.php.net/
[mysql]: http://dev.mysql.com/doc/refman/5.6/en/
[nginx]: http://nginx.org/ "Nginx"
[SPDY]: http://www.chromium.org/spdy "SPDY"
[SASS]: http://sass-lang.com/
[Vagrant]: http://vagrantup.com/
[Compass]: http://compass-style.org/
[yui_comp]: http://developer.yahoo.com/yui/compressor/
[vbox_dl]: https://www.virtualbox.org/wiki/Downloads "Virtualbox Download Page"
[vbox_clone]: http://www.virtualbox.org/manual/ch05.html#cloningvdis "Virtualbox Manual: Cloning disk images"
[github_ssh]: https://help.github.com/articles/generating-ssh-keys
[adayinthepit_ssl_certs]: http://adayinthepit.com/2012/03/21/self-signed-ssl-certificate-nginx-and-rightscale/
[nginx_config_doc]: http://wiki.nginx.org/Configuration
[how_to_forge_phpfpm_nginx]: http://www.howtoforge.com/installing-php-5.3-nginx-and-php-fpm-on-ubuntu-debian
