###
# This makefile more or less automates the procedures set out at
# https://github.com/triplepoint/web_development_vm_how_to
#
# Please refer to that guide for more information.
###


### Global configuration
SHELL := /usr/bin/env bash
TOOL_DIR = $(CURDIR)
SOURCE_DOWNLOAD_DIR = $(TOOL_DIR)/source_downloads
WORKING_DIR = /tmp/makework

### Symlink target for /var/www
WWW_DIRECTORY_SYMLINK_TARGET = /projects

### Nginx Configuration
NGINX_VERSION = 1.4.2

### PHP Configuration
PHP_VERSION = 5.5.1


target-list :
	@echo "This makefile builds tools from source for a PHP-enabled web server."
	@echo
	@echo "To build the server:"
	@echo "    make php_web_server"
	@echo


php_web_server : clean aptget_update firewall_config www_directory_symlink git_install yuicompressor_install compass_install memcached_install mysql_install nginx_install php_install composer_install


###############################################################


purge :
	-rm -rf $(SOURCE_DOWNLOAD_DIR)


clean :
	-rm -rf $(WORKING_DIR)


aptget_update :
	apt-get update


firewall_config :
	ufw default deny
	ufw allow ssh
	ufw allow http
	ufw allow 443
	ufw --force enable


www_directory_symlink :
	-ln -s $(WWW_DIRECTORY_SYMLINK_TARGET) /var/www


git_install :
	apt-get install -y git-core


composer_install :
	apt-get install -y curl
	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) &&     \
	curl -sS https://getcomposer.org/installer | php && \
	mv composer.phar /usr/local/bin/composer


yuicompressor_install :
	apt-get install -y yui-compressor


compass_install :
	apt-get install -y ruby-compass


memcached_install :
	apt-get install -y memcached


mysql_install :
	apt-get install -y mysql-server mysql-client


cache_nginx_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/nginx-$(NGINX_VERSION).tar.gz ]; then	\
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) &&		\
		wget http://nginx.org/download/nginx-$(NGINX_VERSION).tar.gz;		\
	fi

install_nginx_dependencies :
	apt-get install -y make libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base

nginx_build : cache_nginx_source install_nginx_dependencies
	mkdir -p $(WORKING_DIR)

	cp $(SOURCE_DOWNLOAD_DIR)/nginx-$(NGINX_VERSION).tar.gz $(WORKING_DIR)
	tar -C $(WORKING_DIR) -xvf $(WORKING_DIR)/nginx-$(NGINX_VERSION).tar.gz

	cd $(WORKING_DIR)/nginx-$(NGINX_VERSION) &&								\
	./configure																\
		--prefix=/usr														\
		--sbin-path=/usr/sbin												\
		--pid-path=/var/run/nginx.pid										\
		--conf-path=/etc/nginx/nginx.conf									\
		--error-log-path=/var/log/nginx/error.log							\
		--http-log-path=/var/log/nginx/access.log							\
		--user=www-data --group=www-data									\
		--with-http_ssl_module												\
		--with-http_spdy_module												\
		--with-ipv6  &&														\
	#																		\
	$(MAKE)

nginx_install : nginx_build
	cd $(WORKING_DIR)/nginx-$(NGINX_VERSION) &&								\
	$(MAKE) install

	# Set up the Nginx init script
	cp $(TOOL_DIR)/etc/init.d/nginx-init /etc/init.d/nginx
	chmod 755 /etc/init.d/nginx

	# Set up the Nginx config file and its config directories
	mkdir -p /etc/nginx/sites-available
	mkdir -p /etc/nginx/sites-enabled

	# Make the log directories
	mkdir -p /var/log/nginx
	chown www-data:www-data /var/log/nginx

	# Finalize set up and copy over all the customized config files
	update-rc.d nginx defaults

	cp $(TOOL_DIR)/etc/nginx/nginx.conf /etc/nginx/
	cp $(TOOL_DIR)/etc/nginx/sites-available/* /etc/nginx/sites-available

	service nginx start


cache_php_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/php-$(PHP_VERSION).tar.bz2 ]; then												\
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) &&													\
		wget http://www.php.net/get/php-$(PHP_VERSION).tar.bz2/from/this/mirror -O php-$(PHP_VERSION).tar.bz2;			\
	fi

install_php_dependencies :
	apt-get install -y make autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev

php_build : cache_php_source install_php_dependencies
	mkdir -p $(WORKING_DIR)

	cp $(SOURCE_DOWNLOAD_DIR)/php-$(PHP_VERSION).tar.bz2 $(WORKING_DIR)
	tar -C $(WORKING_DIR) -xvf $(WORKING_DIR)/php-$(PHP_VERSION).tar.bz2

	cd $(WORKING_DIR)/php-$(PHP_VERSION) &&									\
	./configure																\
		--prefix=/usr														\
		--sysconfdir=/etc/php												\
		--with-config-file-path=/etc/php									\
		--enable-fpm														\
		--with-fpm-user=www-data											\
		--with-fpm-group=www-data											\
		--enable-opcache 													\
		--enable-mbstring													\
		--enable-mbregex													\
		--with-mysqli														\
		--with-openssl														\
		--with-curl															\
		--with-zlib &&														\
	#																		\
	$(MAKE)

php_install : php_build
	cd $(WORKING_DIR)/php-$(PHP_VERSION) &&									\
	$(MAKE) install

	# Set up the PHP FPM init script
	cp $(WORKING_DIR)/php-$(PHP_VERSION)/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
	chmod 755 /etc/init.d/php-fpm

	# Set up PHP FPM config file, configured to work with the Nginx socket as configured in Nginx earlier
	cp /etc/php/php-fpm.conf.default /etc/php/php-fpm.conf
	sed -i 's/;pid = /pid = /g' /etc/php/php-fpm.conf
	sed -i 's/;error_log = log\/php-fpm.log/error_log = \/var\/log\/php-fpm\/php-fpm.log/g' /etc/php/php-fpm.conf
	sed -i 's/listen = 127.0.0.1:9000/listen = \/tmp\/php.socket/g' /etc/php/php-fpm.conf

	# Make the log directories
	mkdir -p /var/log/php-fpm
	chown www-data:www-data /var/log/php-fpm
	mkdir -p /var/log/php
	chown www-data:www-data /var/log/php

	# Finalize set up and copy over all the customized config files
	update-rc.d php-fpm defaults

	pecl update-channels
	printf "\n" | pecl install pecl_http xdebug

	mkdir -p /etc/php
	cp $(TOOL_DIR)/etc/php.ini /etc/php/php.ini

	service php-fpm start
