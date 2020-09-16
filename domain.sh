#!/bin/bash
# -----------------------------------------------------------------------------------
#
# Assigns a domain to the Laravel Application
#
# Written by Akash Mitra (Twitter @aksmtr)
#
# Version 0.1
#
# -----------------------------------------------------------------------------------
VERSION=0.1
set -o pipefail
export DEBIAN_FRONTEND=noninteractive
function log ()   { echo "${1}"; }
function If_Error_Exit () {
  if [ $? -ne 0 ]; then
    log "${@}"
    exit -1
  fi
}

# booty.sh generally creates application folder
# under /var/www/app.
APP_ROOT="/var/www/app"


# Validate the pre-conditions for running this script
# -----------------------------------------------------------------------------------
if [ `id -u` != "0" ]; then
  log "Run this script as root."
  exit -1
else
  log "Initiating Setup script version: $VERSION as root"
fi


# Validate one parameter is passed
# -----------------------------------------------------------------------------------
if [ $# -ne 1 ]; then
    log "Provide exactly 1 parameter: Domain Name (e.g. example.com)"
    exit -1
fi
DOMAIN_NAME="$1"


# Start installation
# -----------------------------------------------------------------------------------
cd ${APP_ROOT}

# change domain name in .env
sudo -u appusr  sed -i "s|^APP_URL=.*$|APP_URL=https://${DOMAIN_NAME}|" ${APP_ROOT}/.env
sudo -u appusr  sed -i "s/^DOMAIN=.*$/DOMAIN=${DOMAIN_NAME}/" ${APP_ROOT}/.env
sudo -u appusr  sed -i "s/^# SESSION_DOMAIN=.*$/SESSION_DOMAIN=.${DOMAIN_NAME}/" ${APP_ROOT}/.env

# change domain name in nginx.conf
sed -i "s|example.com|${DOMAIN_NAME}|g" /etc/nginx/sites-enabled/app

# restart nginx
systemctl reload nginx                                 >> /dev/null
If_Error_Exit "Failed to reload nginx."
service php7.4-fpm restart                             >> /dev/null
If_Error_Exit "Failed to reload PHP-FPM."


# certbot
# At the moment www version of the site is not being
# secured. Later additional -d www.${DOMAIN_NAME}
# options can be specified.
certbot --nginx \
  --noninteractive \
  --agree-tos \
  -m akash.mitra@gmail.com \
  -d ${DOMAIN_NAME}

certbot renew --dry-run
