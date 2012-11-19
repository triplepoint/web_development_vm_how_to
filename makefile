###
# This makefile more or less automates the procedures set out at
# https://github.com/triplepoint/web_development_vm_how_to
#
###

### Global configuration
SHELL := /usr/bin/env bash
WORKING_DIR = "/tmp/vagrant_make"
TOOL_DIR = $(CURDIR)

### Git configuration
### NOTE: these values configure git's global user attributes,
### and should probably be set to something more useful for you.
GIT_USER_FULL_NAME     = "Jonathan Hanson"
GIT_USER_EMAIL_ADDRESS = "jonathan@jonathan-hanson.org"

### Nginx Configuration
NGINX_VERSION = 1.3.8

### PHP Configuration
PHP_VERSION = 5.4.8


all : target-list


target-list :
	@echo "This makefile is capable of building multiple versions of a the web development server.  Please"
	@echo "choose one by running make <type> with one of the types listed below."
	@echo
	@echo "Available types:"
	@echo "    development_server"
	@echo


development_server : firewall nginx self_signed_cert php mysql compass yui_compressor config_git


firewall :
	ufw default deny
	ufw allow ssh
	ufw allow http
	ufw allow 443
	ufw enable


nginx :
	apt-get update && apt-get install -y libc6 libpcre3 libpcre3-dev libpcrecpp0 libssl0.9.8 libssl-dev zlib1g zlib1g-dev lsb-base

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	# \
	wget http://nginx.org/download/nginx-$(NGINX_VERSION).tar.gz && \
	tar -xvf nginx-$(NGINX_VERSION).tar.gz && \
	# \
	cd nginx-$(NGINX_VERSION) && \
	# \
	#wget http://nginx.org/patches/spdy/patch.spdy.txt && \
	#patch -p0 < patch.spdy.txt && \
	# \
	./configure --prefix=/usr --sbin-path=/usr/sbin --pid-path=/var/run/nginx.pid --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --user=www-data --group=www-data --with-http_ssl_module --with-ipv6  && \
	$(MAKE) && \
	$(MAKE) install

	rm -rf $(WORKING_DIR)

	cp $(TOOL_DIR)/etc/init.d/nginx-init /etc/init.d/nginx
	chmod 755 /etc/init.d/nginx
	update-rc.d nginx defaults

	mkdir -p /var/log/nginx

	mkdir -p /etc/nginx/sites-available
	mkdir -p /etc/nginx/sites-enabled
	cp $(TOOL_DIR)/etc/nginx/nginx.conf /etc/nginx/
	cp $(TOOL_DIR)/etc/nginx/sites-available/* /etc/nginx/sites-available
	ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

	#cp /etc/nginx/sites-available/example /etc/nginx/sites-available/project_name && \
	#ln -s /etc/nginx/sites-available/project_name /etc/nginx/sites-enabled/project_name && \

	service nginx start


self_signed_cert :
	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	#openssl genrsa -des3 -out project_name.key 4096 && \
	## Enter a password to protect this key
	#openssl req -new -key project_name.key -out project_name.csr && \
	## Enter the password from the key above
	## Answer the questions appropriately (ex, 'US', 'California', 'San Francisco', 'No Company', 'No Org', '*.local_server_name.local', 'email@email.com', '', '' )
	## Note that the common name should be the domain you intend to access (ie, '*.local_server_name.local')
	## Note to leave the password blank.
	#openssl rsa -in project_name.key -out project_name.nginx.key && \
	## Enter the password from the key above
	#openssl x509 -req -days 3650 -in project_name.csr -signkey project_name.nginx.key -out project_name.nginx.crt && \
	#cp project_name.nginx.crt /etc/ssl/certs/ && \
	#cp project_name.nginx.key /etc/ssl/private/ && \
	# \
	rm -rf $(WORKING_DIR)


php :
	apt-get update && apt-get install -y autoconf libxml2 libxml2-dev libcurl3 libcurl4-gnutls-dev libmagic-dev

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	# \
	wget http://us3.php.net/get/php-$(PHP_VERSION).tar.bz2/from/us2.php.net/mirror -O php-$(PHP_VERSION).tar.bz2 && \
	tar -xvf php-$(PHP_VERSION).tar.bz2 && \
	# \
	cd php-$(PHP_VERSION) && \
	# \
	./configure --prefix=/usr --sysconfdir=/etc --with-config-file-path=/etc --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --enable-mbstring --with-mysqli --with-openssl --with-zlib && \
	$(MAKE) && \
	$(MAKE) install && \
	# \
	cp php.ini-production /etc/php.ini && \
	# \
	cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm && \
	chmod 755 /etc/init.d/php-fpm && \
	update-rc.d php-fpm defaults

	rm -rf $(WORKING_DIR)

	cp /etc/php-fpm.conf.default /etc/php-fpm.conf
	sed -i 's/;pid = /pid = /g' /etc/php-fpm.conf
	sed -i 's/;error_log = log\/php-fpm.log/error_log = \/var\/log\/php-fpm\/php-fpm.log/g' /etc/php-fpm.conf
	sed -i 's/listen = 127.0.0.1:9000/listen = \/tmp\/php.socket/g' /etc/php-fpm.conf

	mkdir -p /var/log/php-fpm

	#pecl update-channels
	#pecl install pecl_http apc-beta xdebug
	#echo 'extension=http.so' >> /etc/php.ini
	#echo 'extension=apc.so' >> /etc/php.ini
	#echo 'zend_extension="/usr/lib/php/extensions/no-debug-non-zts-20100525/xdebug.so"' >> /etc/php.ini

	service php-fpm start

	ln -s /vagrant_development /var/www


mysql :
	apt-get update && apt-get install -y mysql-server-5.5


compass :
	apt-get update && apt-get install -y ruby
	gem install compass
	ln -s /usr/local/bin/compass /usr/bin/compass


yui_compressor :
	apt-get update && apt-get install -y unzip default-jre

	mkdir -p $(WORKING_DIR) && cd $(WORKING_DIR) && \
	# \
	wget http://yui.zenfs.com/releases/yuicompressor/yuicompressor-2.4.7.zip && \
	unzip yuicompressor-2.4.7.zip && \
	mkdir -p /usr/share/yui-compressor && \
	cp yuicompressor-2.4.7/build/yuicompressor-2.4.7.jar /usr/share/yui-compressor/yui-compressor.jar

	rm -rf $(WORKING_DIR)


config_git :
	git config --global user.name $(GIT_USER_FULL_NAME)
	git config --global user.email $(GIT_USER_EMAIL_ADDRESS)
