#!/bin/bash
#
# Configure a droplet for BlogTheory installation
# Written by Akash Mitra (akash.mitra@gmail.com)
# 
# Written for Ubuntu 18.04 LTS
# Version 0.3
#
#

VERSION="0.3"
set -o pipefail

# Environment variables - setting default log level to info
[ -z "${LOG_LEVEL}" ] && LOG_LEVEL="6" # 7 = debug -> 0 = emergency
__DIR__="$(cd "$(dirname "${0}")"; echo $(pwd))"
__BASE__="$(basename "${0}")"
__FILE__="${__DIR__}/${__BASE__}"
export DEBIAN_FRONTEND=noninteractive

# generic functions
# -----------------------------------------------------------------------------
# Logging functions based on type of messages
function critical ()  { [ "${LOG_LEVEL}" -ge 2 ] && log "FATAL ERROR: $1" || true; }
function error ()     { [ "${LOG_LEVEL}" -ge 3 ] && log "ERROR: $1" || true; }
function warning ()   { [ "${LOG_LEVEL}" -ge 4 ] && log "WARNING: $1" || true; }
function info ()      { [ "${LOG_LEVEL}" -ge 6 ] && log "$1" || true; }
function debug ()     { [ "${LOG_LEVEL}" -ge 7 ] && log "DEBUG: $1" || true; }
function log () { echo "`hostname` | `date '+%F | %H:%M:%S |'` $1"; }
function If_Error_Exit () {
  if [ $? -ne 0 ]; then
    critical "${@}"
    exit -1
  fi
}
# Information gathered here will be emailed to the user later
function gather () {
  echo "[*] ${@}" >> /root/you_must_read_me.txt
}
function update_change_log () {
  echo "${CHANGE_ID} | `date "+%F | %H:%M:%S"` | $1 | $2"  >> /root/system_change_log
  ((GLOBAL_CHANGE_ID++))
  printf -v CHANGE_ID "%05d" $GLOBAL_CHANGE_ID
  CHANGE_STAMP="Line modified by Fairy below. Refer ${CHANGE_ID}"
}

# -----------------------------------------------------------------------------
# Initial checks
# -----------------------------------------------------------------------------
# check application repo is provided in command line
if [ $# -ne 1 ]; then
  help "Application code repo is not supplied in command line"
  exit -1
else
  GIT_REPO_URL=$1
fi
# if not root, get out
if [ `id -u` != "0" ]; then
  help "Run this ${__FILE__} as root"
  exit -1
else
  info "Initiating Setup script version: $VERSION as root"
fi


# -----------------------------------------------------------------------------
# configurable parameters
# -----------------------------------------------------------------------------
# specify the domain name of the website
DOMAIN_NAME='kayna.com'

# specify an SSH connection port. Leave this blank if you want to continue with the default port (22)
SSH_PORT=2222

# -----------------------------------------------------------------------------
# default parameters
# -----------------------------------------------------------------------------
SITEUSER='appuser'
WEBROOT='/var/www'
PORT=80
APC_CACHE_MEM_SIZE="64M"
PHP_POST_MAX_SIZE="5M"
FPM_POOL_DIR="/etc/php/7.2/fpm/pool.d"
MEMCACHED_CONFIG="/etc/memcached.conf"
FASTCGI_PARAM="/etc/nginx/fastcgi_params"
MARIA_DB_SIGNING_KEY="0xF1656F24C74CD1D8"
MARIA_DB_VERSION="10.3"
PHP_SESSION_HANDLER="memcached"
MEMCACHED_TCP_PORT="" #29216 
SESSION_SAVE_PATH=""
FLAVOR="bionic"
CHANGE_ID="00001"
GLOBAL_CHANGE_ID=1
CHANGE_STAMP="Line modified by Fairy below. Refer 00001"
PHP_SERVER_CONFIG="/etc/php/7.2/fpm/php.ini"
MEMCACHED_IPC_SOCKET_PATH="/tmp/memcached.sock"
SITENAME='kayna'
DO=1 # change to 1 if installing in Digital Ocean
REPONAME=`echo $GIT_REPO_URL | rev | cut -d'/' -f1 | cut -d'.' -f2 | rev`



# This is generic package update and upgrade script
# -----------------------------------------------------------------------------
info "Updating/upgrading System (this will take time)"
apt-get --assume-yes --quiet  update                   >> /dev/null
apt-get --assume-yes --quiet  dist-upgrade             >> /dev/null
If_Error_Exit "Failed to update the system"
echo "-----------------------------------------------------------------------" >> /root/you_must_read_me.txt
echo "READ ME                                                                " >> /root/you_must_read_me.txt
echo "Generated by Booty (Version ${VERSION}) Automated installation script    " >> /root/you_must_read_me.txt
echo "Date: `date '+%F | %H:%M'`. (c) Akash Mitra [akashmitra@gmail.com]     " >> /root/you_must_read_me.txt
echo "-----------------------------------------------------------------------" >> /root/you_must_read_me.txt
gather "IMPORTANT: Refer file /root/system_change_log for details of configuration changes"
gather "System Details: `uname -a`"
gather "IP address is : `ifconfig eth0 | grep "inet " | cut -d':' -f2 | cut -d' ' -f1`"



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Environment related tweaks                         #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
if [ $DO -eq 1 ]; then
  info "Adding some swap space..."
  fallocate -l 1G /swapfile # creates SWAP space
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  sysctl vm.swappiness=10
  sysctl vm.vfs_cache_pressure=50
  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
fi
apt-get install software-properties-common --assume-yes  --quiet
add-apt-repository universe


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                INSTALL NGINX                                #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

# install nginx
# -----------------------------------------------------------------------------
info "Installing nginx"
apt-get --assume-yes --quiet install nginx            >> /dev/null
If_Error_Exit "Unable to install Nginx" 
info "Nginx Istalled"

info "Fetching application code from Git repo"
[ -d ${WEBROOT}/${SITENAME} ] || mkdir ${WEBROOT}/${SITENAME}
cd ${WEBROOT}/${SITENAME}
git clone --quiet ${GIT_REPO_URL}
If_Error_Exit "Unable to clone git repo ${GIT_REPO_URL}" 
info "Application code downloaded"

# create user, directory structure and files for webserver
info "Creating user [${SITEUSER}] and web directory [${WEBROOT}/${SITENAME}/${REPONAME}]" 
mkdir ${WEBROOT}/${SITENAME}/logs
useradd -b ${WEBROOT}/${SITENAME} -d ${WEBROOT}/${SITENAME}/${REPONAME} -s /bin/false ${SITEUSER} 
If_Error_Exit "Unable to create user [${SITEUSER}]"
info "User ${SITEUSER} created for web directory ${WEBROOT}/${SITENAME}/${REPONAME}"
chmod 755 ${WEBROOT}/${SITENAME}/${REPONAME}
# change ownership
chown -R ${SITEUSER}:${SITEUSER} ${WEBROOT}/${SITENAME}/*

# modifying nginx config
# -----------------------------------------------------------------------------
info "Configuring nginx server"
sed -i "s/server_tokens off;.*$/# ${CHANGE_STAMP} \nserver_tokens off;/" /etc/nginx/nginx.conf


# create a server block for nginx
# -----------------------------------------------------------------------------
rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default
echo "# Expires map for cache control header"                                  >  /etc/nginx/sites-available/${SITENAME}
echo "map \$sent_http_content_type \$expires {"                                >>  /etc/nginx/sites-available/${SITENAME}
echo "    text/css                   max;"                                     >>  /etc/nginx/sites-available/${SITENAME}
echo "    application/javascript     max;"                                     >>  /etc/nginx/sites-available/${SITENAME}
echo "    ~image/                    max;"                                     >>  /etc/nginx/sites-available/${SITENAME}
echo "}"                                                                       >>  /etc/nginx/sites-available/${SITENAME}
echo "fastcgi_cache_path /etc/nginx/cache levels=1:2 keys_zone=MYAPP:100m inactive=60m;" >>  /etc/nginx/sites-available/${SITENAME}
echo "fastcgi_cache_key \"\$scheme\$request_method\$host\$request_uri\";"      >> /etc/nginx/sites-available/${SITENAME}
echo "server {"                                                                >> /etc/nginx/sites-available/${SITENAME}
echo "        listen ${PORT};"                                                 >> /etc/nginx/sites-available/${SITENAME}
# echo "        listen [::]:${PORT};"                                            >> /etc/nginx/sites-available/${SITENAME}
echo "        server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};"                  >> /etc/nginx/sites-available/${SITENAME}
echo "        root ${WEBROOT}/${SITENAME}/${REPONAME}/public;"                 >> /etc/nginx/sites-available/${SITENAME}
echo "        access_log ${WEBROOT}/${SITENAME}/logs/access.log;"              >> /etc/nginx/sites-available/${SITENAME}
echo "        error_log  ${WEBROOT}/${SITENAME}/logs/error.log;"               >> /etc/nginx/sites-available/${SITENAME}
echo "        index index.html index.php;"                                     >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "        expires \$expires;"                                              >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "        add_header X-Frame-Options \"sameorigin\";"                      >> /etc/nginx/sites-available/${SITENAME}
echo "        add_header X-XSS-Protection \"1; mode=block\";"                  >> /etc/nginx/sites-available/${SITENAME}
echo "        add_header X-Content-Type-Options \"nosniff\";"                  >> /etc/nginx/sites-available/${SITENAME}
echo "        add_header X-Cache \$upstream_cache_status;"                     >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "        charset utf-8;"                                                  >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "        location / {"                                                    >> /etc/nginx/sites-available/${SITENAME}
echo "                try_files \$uri \$uri/ /index.php?\$query_string;"       >> /etc/nginx/sites-available/${SITENAME}
echo "        }"                                                               >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "        location = /favicon.ico { access_log off; log_not_found off; }"  >> /etc/nginx/sites-available/${SITENAME}
echo "        location = /robots.txt  { access_log off; log_not_found off; }"  >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "        error_page 404 /index.php;"                                      >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "        location ~ /\.(?!well-known).* { deny all; }"                    >> /etc/nginx/sites-available/${SITENAME}
echo "        location ~ ~$ { access_log off; log_not_found off; deny all; }"  >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "}"                                                                       >> /etc/nginx/sites-available/${SITENAME}
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/${SITENAME} /etc/nginx/sites-enabled/${SITENAME}
/etc/init.d/nginx reload
If_Error_Exit "Can not enable server [${SITENAME}]"
info "${SITENAME} Enabled successfully"
gather "Root directory of ${SITENAME} is located at ${WEBROOT}/${SITENAME}/${REPONAME}/public"



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                INSTALL PHP                                  #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Updating package lists"
apt-get --assume-yes --quiet update                                                          >> /dev/null

info "Installing PHP with FastCGI Process Manager (PHP-FPM)"
apt-get --assume-yes --quiet install php-fpm php-gd php-apcu php-cli php-curl 2>&1 1> /dev/null
If_Error_Exit "Can not install PHP fpm"
info "PHP FPM installed successfully"
info "Installing memcached for PHP caching"
apt-get --assume-yes --quiet install memcached php-memcached                                2>&1 1> /dev/null
If_Error_Exit "Memcached installation failed"

# configuring php settings
# ----------------------------------------------------------------------------- 
info "Configuring PHP settings"
info "... setting PHP maximum post size to ${PHP_POST_MAX_SIZE}"
sed -i "s/^post_max_size =.*$/; ${CHANGE_STAMP} \npost_max_size = ${PHP_POST_MAX_SIZE}/" $PHP_SERVER_CONFIG
update_change_log "$PHP_SERVER_CONFIG" "set PHP maximum post size to ${PHP_POST_MAX_SIZE}"

info "... setting PHP's session cache handler to $PHP_SESSION_HANDLER"
sed -i "s/^.*session.save_handler = .*$/; ${CHANGE_STAMP} \nsession.save_handler = ${PHP_SESSION_HANDLER}/g" $PHP_SERVER_CONFIG
update_change_log "$PHP_SERVER_CONFIG" "set PHP's session handler to ${PHP_SESSION_HANDLER}"

# check if memcached configured to listen to Unix socket or TCP socket
if [ "${MEMCACHED_TCP_PORT}" == "" ]; then
  # we are using Unix Socket
  info "... creating IPC channel (Unix socket) between memcached and PHP"
  SESSION_SAVE_PATH="${MEMCACHED_IPC_SOCKET_PATH}:0"
else
  # we are using TCP socket
  info "... creating TCP connection between memcached and PHP"
  SESSION_SAVE_PATH="127.0.0.1:${MEMCACHED_TCP_PORT}"
fi


info "... setting session save_path to ${SESSION_SAVE_PATH}"
sed -i "s~^;session.save_path =.*$~; ${CHANGE_STAMP} \nsession.save_path = ${SESSION_SAVE_PATH}~" $PHP_SERVER_CONFIG
update_change_log "$PHP_SERVER_CONFIG" "set PHP's session save_path to ${SESSION_SAVE_PATH}"

info "... Creating a dummy php file for test"
echo "<?php echo 'Current script owner: ' . get_current_user() . '<br />' . 'Server: ' . \$_SERVER['SERVER_ADDR']; ?> " >> ${WEBROOT}/${SITENAME}/${REPONAME}/public/info.php

# change ownership
# chown -R ${SITEUSER}:${SITEUSER} ${WEBROOT}/${SITENAME}/${REPONAME}/public/*
gather "A dummy file is created for testing in website's root directory: info.php"
gather "DO NOT FORGET TO DELETE THE ABOVE FILES ONCE YOUR SERVER IS TESTED OK"


# configuring APC setting
# ----------------------------------------------------------------------------- 
info "Setting APC's (PHP's opcode cache) memory size to ${APC_CACHE_MEM_SIZE}"
echo "${CHANGE_STAMP}"  >> /etc/php/7.2/mods-available/apcu.ini
echo "apc.shm_size = ${APC_CACHE_MEM_SIZE}" >> /etc/php/7.2/mods-available/apcu.ini
update_change_log "/etc/php/7.2/mods-available/apcu.ini" "setting APC's memory size to ${APC_CACHE_MEM_SIZE}"


# configuring php-fpm pool setting
# ----------------------------------------------------------------------------- 
info "Configuring nginx php-fpm pool"
cp ${FPM_POOL_DIR}/www.conf ${FPM_POOL_DIR}/${SITENAME}.conf

info "... renaming pool block to [${SITENAME}]"
sed -i "s/^\[www\]$/\[${SITENAME}\]/" ${FPM_POOL_DIR}/${SITENAME}.conf

info "... changing unix user and group"
sed -i "s/^user = www-data$/; ${CHANGE_STAMP} \nuser = ${SITEUSER}/" ${FPM_POOL_DIR}/${SITENAME}.conf
sed -i "s/^group = www-data$/group = ${SITEUSER}/" ${FPM_POOL_DIR}/${SITENAME}.conf
update_change_log "${FPM_POOL_DIR}/${SITENAME}.conf" "change user and group name to ${SITEUSER}"
sed -i "s/^;listen.owner = www-data$/; ${CHANGE_STAMP} \nlisten.owner = ${SITEUSER}/" ${FPM_POOL_DIR}/${SITENAME}.conf
sed -i "s/^;listen.group = www-data$/listen.group = ${SITEUSER}/" ${FPM_POOL_DIR}/${SITENAME}.conf
update_change_log "${FPM_POOL_DIR}/${SITENAME}.conf" "change listen.user and listen.group name to ${SITEUSER}"

info "... adjusting buffer allocation by nginx for FastCGI"
echo ""                                                     >> ${FASTCGI_PARAM}
echo "# ${CHANGE_STAMP}"                                    >> ${FASTCGI_PARAM}
echo "fastcgi_buffer_size          128k;"                   >> ${FASTCGI_PARAM}
echo "fastcgi_buffers              4 256k;"                 >> ${FASTCGI_PARAM}
echo "fastcgi_busy_buffers_size    256k;"                   >> ${FASTCGI_PARAM}
update_change_log "${FASTCGI_PARAM}" "Added fastcgi buffer size parameters"

debug "Backup the current www.conf from ${FPM_POOL_DIR}"
mv ${FPM_POOL_DIR}/www.conf ${FPM_POOL_DIR}/default.conf.bkp



# configuring memcached setting
# ----------------------------------------------------------------------------- 
info "Configure memcached setting"  
# to be configured for Unix domain socket connection
sed -i "/-p 11211/ s/^#*/# ${CHANGE_STAMP} \n#/"     ${MEMCACHED_CONFIG}
update_change_log "${MEMCACHED_CONFIG}" "Commenting out port switch (-p) as Unix socket will be used"

sed -i "/-l 127.0.0.1/ s/^#*/# ${CHANGE_STAMP} \n#/" ${MEMCACHED_CONFIG}
update_change_log "${MEMCACHED_CONFIG}" "Commenting out listen switch (-l) as Unix socket will be used"

echo ""                                >> ${MEMCACHED_CONFIG}
echo "# ${CHANGE_STAMP}"               >> ${MEMCACHED_CONFIG}
echo "-s ${MEMCACHED_IPC_SOCKET_PATH}" >> ${MEMCACHED_CONFIG}
echo "-a 0755"                         >> ${MEMCACHED_CONFIG}
update_change_log "${MEMCACHED_CONFIG}" "Setting unix socket to ${MEMCACHED_IPC_SOCKET_PATH}"


# Turning on PHP for virtual hosting
# ----------------------------------------------------------------------------- 
info "Turning on PHP for virtual hosting"
info "... configuring Nginx to talk to PHP using Unix socket"
info "... defining upstream variable [php-fpm-sock] under [/etc/nginx/conf.d/]"
echo "upstream php-fpm-sock {"                 > /etc/nginx/conf.d/php-sock.conf
echo "    server unix:/var/run/php/php7.2-fpm.sock;" >> /etc/nginx/conf.d/php-sock.conf
echo "}"                                       >> /etc/nginx/conf.d/php-sock.conf
info "... preparing the virtual host file under sites-available"
sed -i '$ d' /etc/nginx/sites-available/${SITENAME}
echo ""                                                                                   >> /etc/nginx/sites-available/${SITENAME}
echo "        location ~ \.php$ {"                                                        >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_split_path_info ^(.+\.php)(/.+)$;"                          >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_pass php-fpm-sock;"                                         >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_index index.php;"                                           >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_cache MYAPP;"                                               >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_cache_valid 200 1m;"                                        >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_cache_bypass \$no_cache;"                                   >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_no_cache \$no_cache;"                                        >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_cache_use_stale updating error timeout invalid_header http_500;" >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_cache_lock on;"                                             >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_ignore_headers Cache-Control Expires Set-Cookie;"           >> /etc/nginx/sites-available/${SITENAME}
echo "                include /etc/nginx/fastcgi_params;"                                 >> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;">> /etc/nginx/sites-available/${SITENAME}
echo "                fastcgi_intercept_errors on;"                                       >> /etc/nginx/sites-available/${SITENAME}
echo "        }"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo ""                                                                                   >> /etc/nginx/sites-available/${SITENAME}
echo "        #Cache everything by default"                                               >> /etc/nginx/sites-available/${SITENAME}
echo "        set \$no_cache 0;"                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "        #Don't cache POST requests"                                                 >> /etc/nginx/sites-available/${SITENAME}
echo "        if (\$request_method = POST)"                                               >> /etc/nginx/sites-available/${SITENAME}
echo "        {"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "                set \$no_cache 1;"                                                   >> /etc/nginx/sites-available/${SITENAME}
echo "        }"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "        #Don't cache if the URL contains a query string"                                                 >> /etc/nginx/sites-available/${SITENAME}
echo "        if (\$query_string != \"\")"                                               >> /etc/nginx/sites-available/${SITENAME}
echo "        {"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "                set \$no_cache 1;"                                                   >> /etc/nginx/sites-available/${SITENAME}
echo "        }"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "        #Don't cache the following URLs"                                                 >> /etc/nginx/sites-available/${SITENAME}
echo "        if (\$request_uri ~* \"/(cp/)\")"                                               >> /etc/nginx/sites-available/${SITENAME}
echo "        {"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "                set \$no_cache 1;"                                                   >> /etc/nginx/sites-available/${SITENAME}
echo "        }"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "        #Don't cache if there is a cookie called PHPSESSID"                                                 >> /etc/nginx/sites-available/${SITENAME}
echo "        if (\$http_cookie = \"PHPSESSID\")"                                               >> /etc/nginx/sites-available/${SITENAME}
echo "        {"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "                set \$no_cache 1;"                                                   >> /etc/nginx/sites-available/${SITENAME}
echo "        }"                                                                          >> /etc/nginx/sites-available/${SITENAME}
echo "}"                                                                                  >> /etc/nginx/sites-available/${SITENAME}

# restarting services
info "Restarting services"
/etc/init.d/nginx restart
If_Error_Exit "Web server failed to restart"
service php7.2-fpm restart
If_Error_Exit "PHP Fpm failed to restart"
service memcached restart
If_Error_Exit "Memcached failed to restart"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                        INSTALL DATABASE (MARIA DB)                          #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

info "Installing Database"

# adding MariaDB repo to source
# ----------------------------------------------------------------------------- 
info "... add the MariaDB repository to our sources list"
# refer https://mariadb.com/kb/en/installing-mariadb-deb-files/
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com $MARIA_DB_SIGNING_KEY                   2>&1 1> /dev/null
If_Error_Exit "Can not add the signing key"
echo ""                                                                                          >> /etc/apt/sources.list
echo "# ${CHANGE_STAMP}"                                                                         >> /etc/apt/sources.list
echo "# MariaDB ${MARIA_DB_VERSION} repository list"                                                             >> /etc/apt/sources.list
echo "# http://downloads.mariadb.org/mariadb/repositories/"                                      >> /etc/apt/sources.list
echo "deb http://ftp.osuosl.org/pub/mariadb/repo/${MARIA_DB_VERSION}/ubuntu ${FLAVOR} main"      >> /etc/apt/sources.list
echo "deb-src http://ftp.osuosl.org/pub/mariadb/repo/${MARIA_DB_VERSION}/ubuntu ${FLAVOR} main"  >> /etc/apt/sources.list
If_Error_Exit "Can not add MariaDB repo to source ist"
update_change_log "/etc/apt/sources.list" "Added MariaDB repo in sources list"

# installing the database
# ----------------------------------------------------------------------------- 
info "... refreshing source list"
apt-get --assume-yes --quiet update                                           >> /dev/null
info "... installing MariaDB version ${MARIA_DB_VERSION}"
# generate a random password
MYSQL_ROOTPWD=`openssl rand -base64 18 | tr -d "=+/"`
gather "MySQL Database Root password is: ${MYSQL_ROOTPWD}"
debconf-set-selections <<< "mariadb-server-${MARIA_DB_VERSION} mysql-server/root_password password ${MYSQL_ROOTPWD}"
debconf-set-selections <<< "mariadb-server-${MARIA_DB_VERSION} mysql-server/root_password_again password ${MYSQL_ROOTPWD}"
apt-get --assume-yes --quiet install mariadb-server php-mysql                >> /dev/null
If_Error_Exit "Databse installation failed!"
/etc/init.d/mysql start
If_Error_Exit "Failed to start database"

# configuring database
# ----------------------------------------------------------------------------- 
info "Configuring database"
info "... adding skip-networking"
sed -i "s/^\[mysqld\]$/\[mysqld]\n# ${CHANGE_STAMP} \nskip-networking\n# /" /etc/mysql/my.cnf
update_change_log "/etc/mysql/my.cnf" "Added 'skip-networking' option"
info "... configure PHP to use unix socket for database connection"
sed -i "s/^mysql.default_socket =.*$/# ${CHANGE_STAMP} \nmysql.default_socket = \/var\/run\/mysqld\/mysqld.sock/" $PHP_SERVER_CONFIG
update_change_log "$PHP_SERVER_CONFIG" "Mapped to MySQL Unix socket"
info "... restarting services"
service php7.2-fpm restart
/etc/init.d/mysql restart
If_Error_Exit "Failed to start database"


# create a new database with new user for the website
# ----------------------------------------------------------------------------- 
info "Generating create_database.sh script"
echo '#!/usr/bin/env bash' > /root/create_database.sh
echo '' >> /root/create_database.sh
echo '# check if root, if not get out' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo 'if [ `id -u` != "0" ]; then' >> /root/create_database.sh
echo '  echo "run as root"' >> /root/create_database.sh
echo '  exit 1' >> /root/create_database.sh
echo 'fi' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo '# check all the variables are passed as command line argument' >> /root/create_database.sh
echo '# if not, show a helpful message and get out' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo 'if [ $# -ne 4 ]; then' >> /root/create_database.sh
echo '  echo "wrong number of argument passed"' >> /root/create_database.sh
echo '  echo "$0 <root account name> <root password> <database name> <user name>"' >> /root/create_database.sh
echo '  exit 1' >> /root/create_database.sh
echo 'fi' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo '# get variables' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo 'MYSQL_TMPFILE="/tmp/add_new_database_file.sql"' >> /root/create_database.sh
echo 'MYSQL_ROOT_NAME="$1"' >> /root/create_database.sh
echo 'MYSQL_ROOT_PASS="$2"' >> /root/create_database.sh
echo 'MYSQL_NAME="$3"' >> /root/create_database.sh
echo 'MYSQL_USER="$4"' >> /root/create_database.sh
echo 'MYSQL_PASS=`openssl rand -base64 18 | tr -d "=+/"`' >> /root/create_database.sh
echo ''  >> /root/create_database.sh
echo '# create a temp .sql file' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo 'touch $MYSQL_TMPFILE' >> /root/create_database.sh
echo 'echo "CREATE DATABASE ${MYSQL_NAME} CHARACTER SET \"utf8\";" >> $MYSQL_TMPFILE' >> /root/create_database.sh
echo 'echo "CREATE USER ${MYSQL_USER}@127.0.0.1 IDENTIFIED BY \"${MYSQL_PASS}\";" >> $MYSQL_TMPFILE' >> /root/create_database.sh
echo 'echo "CREATE USER ${MYSQL_USER}@localhost IDENTIFIED BY \"${MYSQL_PASS}\";" >> $MYSQL_TMPFILE' >> /root/create_database.sh
echo 'echo "GRANT ALL PRIVILEGES ON ${MYSQL_NAME}.* TO ${MYSQL_USER}@127.0.0.1;" >> $MYSQL_TMPFILE' >> /root/create_database.sh
echo 'echo "GRANT ALL PRIVILEGES ON ${MYSQL_NAME}.* TO ${MYSQL_USER}@localhost;" >> $MYSQL_TMPFILE' >> /root/create_database.sh
echo 'echo "flush privileges;" >> $MYSQL_TMPFILE' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo 'cat $MYSQL_TMPFILE | mysql -u${MYSQL_ROOT_NAME} -p${MYSQL_ROOT_PASS} ' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo 'if [ $? -ne 0 ]; then' >> /root/create_database.sh
echo '  echo "Failed to create databse with new user"' >> /root/create_database.sh
echo '  rm $MYSQL_TMPFILE' >> /root/create_database.sh
echo '  exit 1' >> /root/create_database.sh
echo 'else' >> /root/create_database.sh
echo '  rm $MYSQL_TMPFILE' >> /root/create_database.sh
echo '  echo "Database $MYSQL_NAME created with user $MYSQL_USER and password $MYSQL_PASS"' >> /root/create_database.sh
echo 'fi' >> /root/create_database.sh
echo '' >> /root/create_database.sh
echo '' >> /root/create_database.sh

# using create_database.sh to create a new database
info "creating new user databse db_${REPONAME}"
bash /root/create_database.sh root ${MYSQL_ROOTPWD} db_${REPONAME} db_${REPONAME}_usr > /tmp/database_details_tmp
If_Error_Exit "Can not create user database"
USER_DB_PASS=`cat /tmp/database_details_tmp | rev | cut -d' ' -f1 | rev`
gather "A new database db_${REPONAME} for user db_${REPONAME}_usr (with password ${USER_DB_PASS}) created in MySQL" 
gather "Use the script /root/create_databse.sh later for adding new databases"
rm -f /tmp/database_details_tmp

# changing permissions to read me files
chmod 0600 /root/you_must_read_me.txt
chmod 0600 /root/system_change_log
chmod 0700 /root/create_database.sh 


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Strengthening SSH                                  #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Strengthening SSH connection"
info "... changing default port"
sed -i "s/Port 22.*$/# ${CHANGE_STAMP} \nPort ${SSH_PORT}/" /etc/ssh/sshd_config
update_change_log "/etc/ssh/sshd_config" "Change SSH port to ${SSH_PORT}"
gather "SSH port changed to ${SSH_PORT}"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Activate Firewall                                  #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Activating the firewall"
info "... setting basic deny rule for all incoming requests"
ufw default deny incoming
sudo ufw default allow outgoing
info "... allowing ssh access from any"
ufw allow ${SSH_PORT}/tcp 
info "... allowing http traffic from any"
ufw allow ${PORT}/tcp
info "... allowing https traffic from any"
ufw allow https
info "... enabling firewall logging"
ufw logging on


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Install PHP Composer                               #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Trying to install composer for PHP..."
apt-get install --assume-yes --quiet unzip php-zip php7.2-mbstring php-xml >>/dev/null
cd /root/
export HOME=/root
export COMPOSER_HOME=/root
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
If_Error_Exit "Failed to load composer."
info "Composer installed"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Install Redis                                      #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Installing redis server..."
apt-get --assume-yes --quiet install redis-server >> /dev/null
If_Error_Exit "Failed to install redis."
info "Redis server installed"
info "Configuring redis as a systemd supervised service..."
sed -i "s/supervised no.*$/# ${CHANGE_STAMP} \nsupervised systemd/" /etc/redis/redis.conf
systemctl restart redis.service
If_Error_Exit "Failed to configure redis."
info "Redis server configuration done"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Install predis                                     #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Installing predis via composer..."
cd ${WEBROOT}/${SITENAME}/${REPONAME}
sudo -H -u ${SITEUSER} bash -c 'composer require predis/predis'
If_Error_Exit "Failed to install predis."
info "predis installed via composer"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Install Supervisor                                 #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Installing supervisor daemon"
apt-get --assume-yes --quiet install supervisor  >> /dev/null
If_Error_Exit "Failed to install supervisor daemon."
echo '[program:laravel-worker]' > /etc/supervisor/conf.d/laravel-worker.conf
echo 'process_name=%(program_name)s_%(process_num)02d' >> /etc/supervisor/conf.d/laravel-worker.conf
echo 'command=php '${WEBROOT}/${SITENAME}/${REPONAME}'/artisan queue:work --sleep=5 --tries=3' >> /etc/supervisor/conf.d/laravel-worker.conf
echo 'autostart=true' >> /etc/supervisor/conf.d/laravel-worker.conf
echo 'autorestart=true' >> /etc/supervisor/conf.d/laravel-worker.conf
echo 'user='${SITEUSER} >> /etc/supervisor/conf.d/laravel-worker.conf
echo 'numprocs=4' >> /etc/supervisor/conf.d/laravel-worker.conf
echo 'redirect_stderr=true' >> /etc/supervisor/conf.d/laravel-worker.conf
echo 'stdout_logfile='${WEBROOT}/${SITENAME}/logs'/worker.log' >> /etc/supervisor/conf.d/laravel-worker.conf
info "supervisor daemon installed and configured"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Configuring application                            #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Configuring application... (this will take time)"
cd ${WEBROOT}/${SITENAME}/${REPONAME}
sudo -H -u ${SITEUSER} bash -c 'composer install'

cp .env.example .env
php artisan key:generate
sed -i "s/^DB_DATABASE=.*$/DB_DATABASE=db_${REPONAME}/" .env
sed -i "s/^DB_USERNAME=.*$/DB_USERNAME=db_${REPONAME}_usr/" .env
sed -i "s/^DB_PASSWORD=.*$/DB_PASSWORD=${USER_DB_PASS}\nDB_SOCKET=\/var\/run\/mysqld\/mysqld.sock/" .env

php artisan migrate
php artisan storage:link
sudo -H -u ${SITEUSER} bash -c 'composer install --optimize-autoloader --no-dev'
php artisan config:cache
#php artisan queue:restart
#php artisan route:cache # MAKE SURE THERE IS NO CLOSURE-BASED ROUTE

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Certbot installation                               #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Preparing system for letsencrypt..."
apt-get update
add-apt-repository ppa:certbot/certbot -y
apt-get update
apt-get install certbot python-certbot-nginx --assume-yes  --quiet

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Finalizing the setup                               #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
info "Finalizing installation..."
chown -R ${SITEUSER}:${SITEUSER} ${WEBROOT}/${SITENAME}/*
supervisorctl reread
supervisorctl update
supervisorctl start laravel-worker:*
apt-get --assume-yes --quiet  update                   >> /dev/null
apt-get --assume-yes --quiet  autoremove               >> /dev/null
history -c
service ssh restart
ufw --force enable 
info "All Done! Rebooting..."
#Reboot services
reboot