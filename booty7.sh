#!/bin/bash
#
# Configures a Digital Ocean droplet for the
# installation of Laravel-based web applications.
#
# Written by Akash Mitra (Twitter @aksmtr)
#
# Written for Ubuntu 18.04 LTS
# Version 0.6
#
# -----------------------------------------------------------------------------------
VERSION="0.7"
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
REPO=0                   # GitHub source code for public repo
SWAP=1                   # Whether to add a swap space
SSH_PORT="24600"         # Default SSH Port Number
VERBOSE=0                # Show verbose information
WEBROOT="/var/www/app"

# Validate the input paramters
# -----------------------------------------------------------------------------------
while (( "$#" )); do
    case "$1" in
    -h|--help)
      HELP=1
      shift     # past argument
      ;;
    -r|--repo)
      REPO="${2}"
      shift     # past the argument
      shift     # past the value
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
    echo "-r | --repo [HTTPS_REPO]    Path to the public Github repository."
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
    curl -s https://raw.githubusercontent.com/akash-mitra/booty/master/add-swap.sh | bash
fi


log "[*] Updating system."
apt-get --assume-yes --quiet  update                   >> /dev/null
apt-get --assume-yes --quiet  dist-upgrade             >> /dev/null



# Start installations
# -----------------------------------------------------------------------------------

log "[*] Installing nginx."
apt-get --assume-yes --quiet install nginx \
    php-fpm \
    php-bcmath \
    php-ctype \
    php-json \
    php-mbstring \
    php-tokenizer \
    php-xml \
    php-gd \
    php-curl >> /dev/null

If_Error_Exit "Unable to install Nginx"

log "[*] Configuring nginx."

# create web directory
[ -d ${WEBROOT} ] || mkdir -p ${WEBROOT}/logs

# add user and group
useradd --home-dir ${WEBROOT} --shell /usr/sbin/nologin appusr
If_Error_Exit "Unable to create user [appusr]"


# change main nginx config file
sed -i "s/# server_tokens off;.*$/server_tokens off;/" /etc/nginx/nginx.conf

# remove original site configs
rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default

# download new site config
curl --silent https://raw.githubusercontent.com/akash-mitra/booty/master/add-swap.sh --output /etc/nginx/sites-available/app
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app


# PHP configuration
log "[*] Configuring PHP with FPM."

PHP_FPM_BASE_DIR='/etc/php/7.2/fpm'
PHP_FPM_CONFIG_FILE=${PHP_FPM_BASE_DIR}/php.ini
PHP_FPM_POOL_CONFIG_FILE=${PHP_FPM_BASE_DIR}/pool.d/www.conf

# Change the maximum size of POST data that PHP will accept.
sed -i "s/^post_max_size =.*$/post_max_size = ${POST_MAX_SIZE}/" $PHP_FPM_CONFIG_FILE

# enable PHP opcode cache
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
sed -i "s/listen.owner = www-data$/listen.owner = appusr/"                              $PHP_FPM_POOL_CONFIG_FILE
sed -i "s/listen.group = www-data$/listen.group = appusr/"                              $PHP_FPM_POOL_CONFIG_FILE
sed -i "s|^listen = /run/php/php7.2-fpm.sock$|listen = /var/run/php/php7.2-fpm.sock|"   $PHP_FPM_POOL_CONFIG_FILE


# Create a test file in the web root
echo "<?php echo 'Current script owner: ' . get_current_user() . '<br />' . 'Server: ' . \$_SERVER['SERVER_ADDR']; ?> " >> /var/www/app/public/info.php

# change the ownership of the files and directories
chmod 755 ${WEBROOT}
chown -R appusr:appusr ${WEBROOT}/*
chown    appusr:appusr /var/run/php/php7.2-fpm.sock

# restart the web server as well as php-fpm services
systemctl reload nginx
If_Error_Exit "Can not enable nginx config."
service php7.2-fpm restart
If_Error_Exit "Can not enable PHP-FPM."
