###
# This makefile more or less automates the procedures set out at
# https://github.com/triplepoint/web_development_vm_how_to
#
###


### Global configuration
SHELL := /usr/bin/env bash
WORKING_DIR = /tmp/makework
TOOL_DIR = $(CURDIR)
SOURCE_DOWNLOAD_DIR = $(TOOL_DIR)/source_downloads


### Git configuration
### NOTE: these values configure git's global user attributes,
### and should probably be set to something more useful for you.
GIT_USER_FULL_NAME     = "Jonathan Hanson"
GIT_USER_EMAIL_ADDRESS = "jonathan@jonathan-hanson.org"

### Nginx Configuration
NGINX_VERSION = 1.3.9

### PHP Configuration
PHP_VERSION = 5.4.9

### Symlink target for /var/www
WWW_DIRECTORY_SYMLINK_TARGET = /vagrant_development

### MySQL Configuration
# Note that the URL this is sourced from is a needlessly-complex URL scheme at mysql.com  Any version other
# than a 5.6.x version will likely require the URL to be reviewed and modified
MYSQL_VERSION = 5.6.8-rc

### YUI Compressor
YUI_COMPRESSOR_VERSION = 2.4.7


target-list :
	@echo "This makefile is capable of building multiple versions of a the web development server.  Please"
	@echo "choose one by running make <type> with one of the types listed below."
	@echo
	@echo "Available types:"
	@echo "    development_server"
	@echo "    production_server"
	@echo


development_server : package_update firewall www_directory_symlink git nginx nginx_default_server php mysql yui_compressor compass


production_server : package_update firewall git nginx php mysql


###############################################################


package_update :
	apt-get update


firewall :
	ufw default deny
	ufw allow ssh
	ufw allow http
	ufw allow 443
	ufw --force enable


www_directory_symlink :
	-ln -s $(WWW_DIRECTORY_SYMLINK_TARGET) /var/www


git :
	apt-get install -y git-core


get_nginx_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/nginx-$(NGINX_VERSION).tar.gz ]; then \
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) && \
		wget http://nginx.org/download/nginx-$(NGINX_VERSION).tar.gz; \
	fi


get_nginx_spdy_patch_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/patch.spdy.txt ]; then \
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) && \
		wget http://nginx.org/patches/spdy/patch.spdy.txt; \
	fi


nginx : get_nginx_source get_nginx_spdy_patch_source
	apt-get install -y libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	# \
	cp $(SOURCE_DOWNLOAD_DIR)/nginx-$(NGINX_VERSION).tar.gz . && \
	tar -xvf nginx-$(NGINX_VERSION).tar.gz && \
	# \
	cd nginx-$(NGINX_VERSION) && \
	# \
	cp $(SOURCE_DOWNLOAD_DIR)/patch.spdy.txt . && \
	patch -p0 < patch.spdy.txt && \
	# \
	./configure 									\
		--prefix=/usr 								\
		--sbin-path=/usr/sbin 						\
		--pid-path=/var/run/nginx.pid 				\
		--conf-path=/etc/nginx/nginx.conf 			\
		--error-log-path=/var/log/nginx/error.log 	\
		--http-log-path=/var/log/nginx/access.log 	\
		--user=www-data --group=www-data 			\
		--with-http_ssl_module 						\
		--with-ipv6  && \
	$(MAKE) && \
	$(MAKE) install

	-rm -rf $(WORKING_DIR)

	cp $(TOOL_DIR)/etc/init.d/nginx-init /etc/init.d/nginx
	chmod 755 /etc/init.d/nginx
	update-rc.d nginx defaults

	mkdir -p /var/log/nginx

	mkdir -p /etc/nginx/sites-available
	mkdir -p /etc/nginx/sites-enabled
	cp $(TOOL_DIR)/etc/nginx/nginx.conf /etc/nginx/
	cp $(TOOL_DIR)/etc/nginx/sites-available/* /etc/nginx/sites-available

	service nginx start


nginx_default_server :
	-ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
	service nginx restart


get_php_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/php-$(PHP_VERSION).tar.bz2 ]; then \
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) && \
		wget http://us3.php.net/get/php-$(PHP_VERSION).tar.bz2/from/us2.php.net/mirror -O php-$(PHP_VERSION).tar.bz2; \
	fi


php : get_php_source
	apt-get install -y autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	# \
	cp $(SOURCE_DOWNLOAD_DIR)/php-$(PHP_VERSION).tar.bz2 . && \
	tar -xvf php-$(PHP_VERSION).tar.bz2 && \
	# \
	cd php-$(PHP_VERSION) && \
	# \
	./configure 						\
		--prefix=/usr 					\
		--sysconfdir=/etc 				\
		--with-config-file-path=/etc 	\
		--enable-fpm 					\
		--with-fpm-user=www-data 		\
		--with-fpm-group=www-data 		\
		--enable-mbstring 				\
		--with-mysqli 					\
		--with-openssl 					\
		--with-zlib && \
	$(MAKE) && \
	$(MAKE) install && \
	# \
	cp php.ini-production /etc/php.ini && \
	sed -i 's/;date.timezone =/date.timezone = UTC/g' /etc/php.ini && \
	# \
	cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm && \
	chmod 755 /etc/init.d/php-fpm && \
	update-rc.d php-fpm defaults

	-rm -rf $(WORKING_DIR)

	# Set up PHP FPM to work with Nginx as configured above
	cp /etc/php-fpm.conf.default /etc/php-fpm.conf
	sed -i 's/;pid = /pid = /g' /etc/php-fpm.conf
	sed -i 's/;error_log = log\/php-fpm.log/error_log = \/var\/log\/php-fpm\/php-fpm.log/g' /etc/php-fpm.conf
	sed -i 's/listen = 127.0.0.1:9000/listen = \/tmp\/php.socket/g' /etc/php-fpm.conf

	mkdir -p /var/log/php-fpm

	# install the PECL extensions
	pecl update-channels
	printf "\n" | pecl install pecl_http apc-beta xdebug
	echo 'extension=http.so' >> /etc/php.ini
	echo 'extension=apc.so' >> /etc/php.ini
	echo 'zend_extension="/usr/lib/php/extensions/no-debug-non-zts-20100525/xdebug.so"' >> /etc/php.ini

	service php-fpm start


mysql_user :
	groupadd -g 40 mysql && \
	useradd -c "MySQL Server" -d /dev/null -g mysql -s /bin/false -u 40 mysql


get_mysql_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/mysql-$(MYSQL_VERSION).tar.gz ]; then \
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) && \
		wget http://cdn.mysql.com/Downloads/MySQL-5.6/mysql-$(MYSQL_VERSION).tar.gz; \
	fi


mysql : get_mysql_source #mysql_user
	### Here's how it would look to build from source (incomplete):
	apt-get install -y build-essential cmake libaio-dev libncurses5-dev

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	# \
	cp $(SOURCE_DOWNLOAD_DIR)/mysql-$(MYSQL_VERSION).tar.gz . && \
	tar -xvf mysql-$(MYSQL_VERSION).tar.gz && \
	# \
	cd mysql-$(MYSQL_VERSION) && \
	mkdir build && cd build && \
	#\
	cmake                                  		 	  \
		-DCMAKE_INSTALL_PREFIX=/usr/share/mysql       \
        -DSYSCONFDIR=/etc                             \
		.. && \
	$(MAKE) && \
	$(MAKE) install

	-rm -rf $(WORKING_DIR)

	cp /usr/share/mysql/support-files/my-default.cnf /etc/my.cnf

	cp /usr/share/mysql/support-files/mysql.server /etc/init.d/mysqld
	chmod 755 /etc/init.d/mysqld
	update-rc.d mysqld defaults

	service mysqld start

java_runtime :
	apt-get install -y unzip default-jre


get_yui_compressor_source :
	@if [ ! -f $(SOURCE_DOWNLOAD_DIR)/yuicompressor-$(YUI_COMPRESSOR_VERSION).zip ]; then \
		mkdir -p $(SOURCE_DOWNLOAD_DIR) && cd $(SOURCE_DOWNLOAD_DIR) && \
		wget https://github.com/downloads/yui/yuicompressor/yuicompressor-$(YUI_COMPRESSOR_VERSION).zip; \
	fi


yui_compressor : java_runtime get_yui_compressor_source
	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	# \
	cp $(SOURCE_DOWNLOAD_DIR)/yuicompressor-$(YUI_COMPRESSOR_VERSION).zip . && \
	unzip yuicompressor-$(YUI_COMPRESSOR_VERSION).zip && \
	# \
	mkdir -p /usr/share/yui-compressor && \
	cp yuicompressor-$(YUI_COMPRESSOR_VERSION)/build/yuicompressor-$(YUI_COMPRESSOR_VERSION).jar /usr/share/yui-compressor/yui-compressor.jar

	-rm -rf $(WORKING_DIR)


ruby :
	apt-get install -y ruby


compass : ruby
	gem install compass
	-ln -s /usr/local/bin/compass /usr/bin/compass
