#!/bin/bash
# -----------------------------------------------------------------------------------
# Configures a Digital Ocean droplet for the
# installation of Laravel-based web applications.
#
# Written by Akash Mitra (Twitter @aksmtr)
#
# Written for Ubuntu 20.04 LTS (PHP 7.4)
# Version 0.8
#
# -----------------------------------------------------------------------------------
VERSION="0.8"
set -o pipefail
export DEBIAN_FRONTEND=noninteractive

function log ()   { echo "${1}"; }
function info ()  { [ "${VERBOSE}" -eq 1 ] && log "${1}" || true; }
function If_Error_Exit () {
  if [ $? -ne 0 ]; then
    log "${@}"
    exit -1
  fi
}


# Default paramters
# -----------------------------------------------------------------------------------
PARAMS=""
HELP=0                   # show help message
SWAP=1                   # Whether to add a swap space
SSH_PORT="22"            # Default SSH Port Number
VERBOSE=0                # Show verbose information
WEBROOT="/var/www"
APPROOT="${WEBROOT}/app"
LOGDIR="${WEBROOT}/logs"
BACKUPDIR="${WEBROOT}/backups"

# Validate the input paramters
# -----------------------------------------------------------------------------------
while (( "$#" )); do
    case "$1" in
    -h|--help)
      HELP=1
      shift     # past argument
      ;;
    -n|--no-swap)
      SWAP=0
      shift     # past the argument
      ;;
    -p|--port)
      SSH_PORT="${2}"
      shift     # past the argument
      shift     # past the value
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done
# set positional arguments in their proper place
eval set -- "$PARAMS"


# Show Help Message
# -----------------------------------------------------------------------------------

if [ $HELP -eq 1 ]; then
    echo -e "\nConfigures a barebone machine for Laravel installation. Supported options: "
    echo "-h | --help                 Show this message."
    echo "-n | --no-swap              Do not add swap space by default."
    echo "-p | --port [SSH_PORT]      SSH Port (Default is 24600)."
    echo "-v | --verbose              Show additional information."
    exit 0
fi


# Validate the pre-conditions for running this script
# -----------------------------------------------------------------------------------
if [ `id -u` != "0" ]; then
  log "Run this script as root."
  exit -1
else
  info "Initiating Setup script version: $VERSION as root"
fi



# Add Additional Swap Space.
# -----------------------------------------------------------------------------------
if [ $SWAP -eq 1 ]; then
    info "[*] Adding Swap space to the server."
    curl -sS https://raw.githubusercontent.com/akash-mitra/booty/master/add-swap.sh | bash >> /dev/null
fi


log "[*] Updating system."
apt-get --assume-yes --quiet  update                   >> /dev/null
apt-get --assume-yes --quiet  dist-upgrade             >> /dev/null

# This ensures that package download happens in HTTPS instead of HTTP
apt-get --assume-yes --quiet  apt-transport-https      >> /dev/null



# Start installations
# -----------------------------------------------------------------------------------

log "[*] Installing nginx."
apt-get --assume-yes --quiet install nginx \
    zip \
    unzip \
    php-bcmath \
    php-ctype \
    php-curl \
    php-fpm \
    php-gd \
    php-json \
    php-mbstring \
    php-mysql \
    php-tokenizer \
    php-xml \
    php-zip >> /dev/null

If_Error_Exit "Unable to install Nginx"

log "[*] Configuring nginx."

# create web directory
[ -d ${WEBROOT} ]    || mkdir -p ${WEBROOT}
[ -d ${APPROOT} ]    || mkdir -p ${APPROOT}
[ -d ${LOGDIR} ]     || mkdir -p ${LOGDIR}
[ -d ${BACKUPDIR} ]  || mkdir -p ${BACKUPDIR}
mkdir ${APPROOT}/public


# add user and group
useradd --home-dir ${WEBROOT} --shell /usr/sbin/nologin appusr
If_Error_Exit "Unable to create user [appusr]"


# change main nginx config file
sed -i "s/# server_tokens off;.*$/server_tokens off;/" /etc/nginx/nginx.conf

# remove original site configs
rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default

# download new site config
curl --silent https://raw.githubusercontent.com/akash-mitra/booty/master/nginx-config-app.sh --output /etc/nginx/sites-available/app
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app


# PHP configuration
log "[*] Configuring PHP with FPM."

PHP_FPM_BASE_DIR='/etc/php/7.4/fpm'
PHP_FPM_CONFIG_FILE=${PHP_FPM_BASE_DIR}/php.ini
PHP_FPM_POOL_CONFIG_FILE=${PHP_FPM_BASE_DIR}/pool.d/www.conf

# Change the maximum size of POST data that PHP will accept.
sed -i "s/^post_max_size =.*$/post_max_size = ${POST_MAX_SIZE}/" $PHP_FPM_CONFIG_FILE

# Enable PHP opcode cache
# Note: We are uning the opcode cache that comes default with PHP > 5.5.
# Please note, since validate timestamp is disabled, you must reset the
# OPcache manually by opcache_reset() PHP function call or restart the
# webserver to ensure any PHP code changes to the filesystem take effect.
sed -i "s/^;opcache.enable=.*$/opcache.enable=1/"                           $PHP_FPM_CONFIG_FILE
sed -i "s/^;opcache.validate_timestamps=.*$/opcache.validate_timestamps=0/" $PHP_FPM_CONFIG_FILE


# Configure PHP-FPM pool for processing PHP requests.
# Since we are using a separate user account to run PHP
# we must tell PHP-FPM the details of this user account.
# Refer: https://gist.github.com/fyrebase/62262b1ff33a6aaf5a54
sed -i "s/^user = www-data$/user = appusr/"                                             $PHP_FPM_POOL_CONFIG_FILE
sed -i "s/^group = www-data$/group = appusr/"                                           $PHP_FPM_POOL_CONFIG_FILE
sed -i "s|^listen = /run/php/php7.4-fpm.sock$|listen = /var/run/php/php7.4-fpm.sock|"   $PHP_FPM_POOL_CONFIG_FILE


# change the ownership of the files and directories
chmod 755 ${WEBROOT}
chown -R appusr:appusr ${WEBROOT}/*

# restart the web server as well as php-fpm services
systemctl reload nginx
If_Error_Exit "Can not enable nginx config."
service php7.4-fpm restart
If_Error_Exit "Can not enable PHP-FPM."



# Install Maria DB
#
log "[*] Installing and Configuring Database."
# MariaDB Corporation provides a MariaDB Package Repository for
# several Linux distributions that use apt to manage packages.
# This MariaDB Package Repository setup script automatically
# configures the system to install packages from the MariaDB
# Package Repository.
# Refer: https://mariadb.com/kb/en/installing-mariadb-deb-files/
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -s -- --skip-maxscale --skip-tools >> /dev/null
apt-get --assume-yes --quiet install mariadb-server \
    mariadb-client \
    libmariadb3 \
    mariadb-backup \
    mariadb-common >> /dev/null

# Secure the installation and create applications users.
# This step will create a database called "appdb" with a user called "dbusr".
# The password for this user will be available under /root/mysql_app_password.
curl -sS https://raw.githubusercontent.com/akash-mitra/booty/master/db-user-setup.sh | bash >> /dev/null

# we are going to configure the PDO datbase driver
# to connect to mysql using unix socket.
sed -i "s/^pdo_mysql.default_socket=.*$/pdo_mysql.default_socket=\/var\/run\/mysqld\/mysqld.sock/" $PHP_FPM_CONFIG_FILE


service mysql restart
If_Error_Exit "Failed to start database"


# Secure the box
#
log "[*] Securing the box."

# change port, and in case PasswordAuthentication is "yes", change to "no".
sed -i "s/.*Port 22.*$/Port ${SSH_PORT}/"                             /etc/ssh/sshd_config
sed -i "s/.*PasswordAuthentication yes.*$/PasswordAuthentication no/" /etc/ssh/sshd_config

# enable firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ${SSH_PORT}/tcp
ufw allow http
ufw allow https
ufw --force enable
ufw status



# Install Laravel Application specific dependencies
#
log "[*] Install Laravel Application specific dependencies."

# install composer
log "[*] - Composer."
cd /root/
export HOME=/root
export COMPOSER_HOME=/root
[ -d /usr/local/bin ] || mkdir -p /usr/local/bin
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >> /dev/null
If_Error_Exit "Failed to load composer."

# install Redis
log "[*] - Redis."
apt-get --assume-yes --quiet install redis-server >> /dev/null
sed -i "s/^supervised no.*$/supervised systemd/" /etc/redis/redis.conf
service redis-server restart

# install Supervisor Daemon
log "[*] - Supervisor Daemon."
apt-get --assume-yes --quiet install supervisor  >> /dev/null
curl -sS https://raw.githubusercontent.com/akash-mitra/booty/master/laravel-worker.conf --output /etc/supervisor/conf.d/laravel-worker.conf

# install certbot
log "[*] - Certbot"
snap install --classic certbot
# after sitename update is done in nginx config, just run:
# certbot --nginx
# certbot renew --dry-run

# chown -R appusr:appusr /etc/letsencrypt
# chown -R appusr:appusr /var/log/letsencrypt
# chown -R appusr:appusr /var/lib/letsencrypt



log "[*] Finalising setup."
chown -R appusr:appusr ${WEBROOT}
supervisorctl reread                                   >> /dev/null
If_Error_Exit "Failed to reread supervisord config."
supervisorctl update                                   >> /dev/null
If_Error_Exit "Failed to update supervisord."
supervisorctl start laravel-worker:*                   >> /dev/null
If_Error_Exit "Failed to start laravel worker."
apt-get --assume-yes --quiet  update                   >> /dev/null
apt-get --assume-yes --quiet  autoremove               >> /dev/null
systemctl reload nginx                                 >> /dev/null
If_Error_Exit "Failed to reload nginx."
service php7.4-fpm restart                             >> /dev/null
If_Error_Exit "Failed to reload PHP-FPM."
service ssh restart                                    >> /dev/null
If_Error_Exit "Failed to load reload sshd."
history -c
echo "All done. Rebooting the box."
reboot