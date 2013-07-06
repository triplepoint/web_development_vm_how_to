###
# This makefile more or less automates the procedures set out at
# https://github.com/triplepoint/web_development_vm_how_to
#
# Please refer to that guide for more information.
###


### Global configuration
SHELL := /usr/bin/env bash
WORKING_DIR = /tmp/makework
TOOL_DIR = $(CURDIR)
SOURCE_DOWNLOAD_DIR = $(TOOL_DIR)/source_downloads



### Nginx Configuration
NGINX_VERSION = 1.4.1

### PHP Configuration
PHP_VERSION = 5.5.0

### Symlink target for /var/www
WWW_DIRECTORY_SYMLINK_TARGET = /projects

### MySQL Configuration
# Note that the URL this is sourced from is a needlessly-complex URL scheme at mysql.com  Any version other
# than a 5.6.x version will likely require the URL to be reviewed and modified.  See down below for where this
# is used in the URL fragment
MYSQL_VERSION = 5.6.12

### YUI Compressor
YUI_COMPRESSOR_VERSION = 2.4.7


target-list :
	@echo "This makefile builds the PHP-enabled web server."
	@echo
	@echo "To build the server:"
	@echo "    make php_web_server"
	@echo


php_web_server : firewall www_directory_symlink nginx php mysql yui_compressor compass


###############################################################


clean :
	-rm -rf $(WORKING_DIR)
	-rm -rf $(SOURCE_DOWNLOAD_DIR)

package_update :
	apt-get update

package_install : package_update
	apt-get install -y  																			\
		git-core 																					\
		libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base 	\
		autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev 						\
		build-essential cmake libaio-dev libncurses5-dev 											\
		unzip default-jre 																			\
		ruby

firewall :
	ufw default deny
	ufw allow ssh
	ufw allow http
	ufw allow 443
	ufw --force enable


www_directory_symlink :
	-ln -s $(WWW_DIRECTORY_SYMLINK_TARGET) /var/www


get_nginx_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/nginx-$(NGINX_VERSION).tar.gz ]; then	\
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) &&		\
		wget http://nginx.org/download/nginx-$(NGINX_VERSION).tar.gz;		\
	fi

nginx_build : package_install get_nginx_source
	# Packages needed: libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) &&							\
	#																		\
	cp $(SOURCE_DOWNLOAD_DIR)/nginx-$(NGINX_VERSION).tar.gz . &&			\
	tar -xvf nginx-$(NGINX_VERSION).tar.gz &&								\
	#																		\
	cd nginx-$(NGINX_VERSION) &&											\
	#																		\
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
	#																		\
	$(MAKE) install

	cp $(TOOL_DIR)/etc/init.d/nginx-init /etc/init.d/nginx
	chmod 755 /etc/init.d/nginx
	update-rc.d nginx defaults

	mkdir -p /var/log/nginx
	chown www-data:www-data /var/log/nginx

	mkdir -p /etc/nginx/sites-available
	mkdir -p /etc/nginx/sites-enabled
	cp $(TOOL_DIR)/etc/nginx/nginx.conf /etc/nginx/
	cp $(TOOL_DIR)/etc/nginx/sites-available/* /etc/nginx/sites-available

	service nginx start


nginx : nginx_install


get_php_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/php-$(PHP_VERSION).tar.bz2 ]; then												\
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) &&													\
		wget http://www.php.net/get/php-$(PHP_VERSION).tar.bz2/from/this/mirror -O php-$(PHP_VERSION).tar.bz2;			\
	fi


php_build : package_install get_php_source
	# Packages needed: autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) &&							\
	#																		\
	cp $(SOURCE_DOWNLOAD_DIR)/php-$(PHP_VERSION).tar.bz2 . &&				\
	tar -xvf php-$(PHP_VERSION).tar.bz2 &&									\
	#																		\
	cd php-$(PHP_VERSION) &&												\
	#																		\
	./configure																\
		--prefix=/usr														\
		--sysconfdir=/etc													\
		--with-config-file-path=/etc										\
		--enable-fpm														\
		--with-fpm-user=www-data											\
		--with-fpm-group=www-data											\
		--enable-opcache    												\
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
	#																		\
	$(MAKE) install &&														\
	#																		\
	# ### Instead of using the provided php.ini, we're using a custom one	\
	# cp php.ini-production /etc/php.ini &&									\
	# sed -i 's/;date.timezone =/date.timezone = UTC/g' /etc/php.ini &&		\
	#																		\
	cp $(TOOL_DIR)/etc/php.ini /etc/php.ini &&								\
	#																		\
	cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm &&						\
	chmod 755 /etc/init.d/php-fpm &&										\
	update-rc.d php-fpm defaults

	# Set up PHP FPM to work with Nginx as configured above
	cp /etc/php-fpm.conf.default /etc/php-fpm.conf
	sed -i 's/;pid = /pid = /g' /etc/php-fpm.conf
	sed -i 's/;error_log = log\/php-fpm.log/error_log = \/var\/log\/php-fpm\/php-fpm.log/g' /etc/php-fpm.conf
	sed -i 's/listen = 127.0.0.1:9000/listen = \/tmp\/php.socket/g' /etc/php-fpm.conf

	mkdir -p /var/log/php-fpm
	chown www-data:www-data /var/log/php-fpm
	mkdir -p /var/log/php
	chown www-data:www-data /var/log/php

	# install the PECL extensions
	pecl update-channels
	printf "\n" | pecl install pecl_http xdebug

	# ### These commands are only necessary if you're modifying the default php.ini.
	# echo 'extension = http.so' >> /etc/php.ini
	# echo 'zend_extension = "/usr/lib/php/extensions/no-debug-non-zts-20121212/xdebug.so"' >> /etc/php.ini

	service php-fpm start


php : php_install


mysql_user :
	groupadd mysql &&														\
	useradd -c "MySQL Server" -r -g mysql mysql


get_mysql_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/mysql-$(MYSQL_VERSION).tar.gz ]; then				\
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) &&					\
		wget http://cdn.mysql.com/Downloads/MySQL-5.6/mysql-$(MYSQL_VERSION).tar.gz;	\
	fi


mysql_build : package_install get_mysql_source mysql_user
	# Packages needed: build-essential cmake libaio-dev libncurses5-dev

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) &&							\
	#																		\
	cp $(SOURCE_DOWNLOAD_DIR)/mysql-$(MYSQL_VERSION).tar.gz . &&			\
	tar -xvf mysql-$(MYSQL_VERSION).tar.gz &&								\
	#																		\
	cd mysql-$(MYSQL_VERSION) &&											\
	mkdir build && cd build &&												\
	#																		\
	cmake																	\
		-DCMAKE_INSTALL_PREFIX=/usr/share/mysql								\
		-DSYSCONFDIR=/etc													\
		.. &&																\
	#																		\
	$(MAKE)


mysql_install : mysql_build
	cd $(WORKING_DIR)/mysql-$(MYSQL_VERSION)/build &&						\
	#																		\
	$(MAKE) install

	# Set up the system tables
	chown -R mysql:mysql /usr/share/mysql
	cd /usr/share/mysql/ && scripts/mysql_install_db --user=mysql
	chown -R root /usr/share/mysql
	chown -R mysql /usr/share/mysql/data

	# Set up the MySQL config file
	cp /usr/share/mysql/support-files/my-default.cnf /etc/my.cnf

	# Set up the init.d files
	cp /usr/share/mysql/support-files/mysql.server /etc/init.d/mysqld
	chmod 755 /etc/init.d/mysqld
	update-rc.d mysqld defaults

	# Start MySQL
	service mysqld start


mysql : mysql_install


get_yui_compressor_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/yuicompressor-$(YUI_COMPRESSOR_VERSION).zip ]; then					\
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) &&										\
		wget https://github.com/downloads/yui/yuicompressor/yuicompressor-$(YUI_COMPRESSOR_VERSION).zip;	\
	fi


yui_compressor : package_install get_yui_compressor_source
	# Packages needed: unzip default-jre

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) &&																								\
	#																																			\
	cp $(SOURCE_DOWNLOAD_DIR)/yuicompressor-$(YUI_COMPRESSOR_VERSION).zip . &&																	\
	unzip yuicompressor-$(YUI_COMPRESSOR_VERSION).zip &&																						\
	#																																			\
	mkdir -p /usr/share/yui-compressor &&																										\
	cp yuicompressor-$(YUI_COMPRESSOR_VERSION)/build/yuicompressor-$(YUI_COMPRESSOR_VERSION).jar /usr/share/yui-compressor/yui-compressor.jar


compass : package_install
	# Packages needed: ruby

	gem install compass
	-ln -s `which compass` /usr/bin/compass
