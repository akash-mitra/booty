#!/bin/bash
# -----------------------------------------------------------------------------------
# Create a laravel application instance directly from
# the Github source repo. This code expects that
# a server is created by booty.sh code first
#
# Written by Akash Mitra (Twitter @aksmtr)
#
# Written for Ubuntu 20.04 LTS
# Version 0.1
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#      RUN THIS SCRIPT ONLY WHEN -
#      (1) The application is a Laravel App
#      (2) The Server is configured with Booty.sh script
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
if [ $# -ne 4 ]; then
    log "Provide exactly 4 parameters: 'Github repo url', 'admin user name', 'admin email' and 'admin password' separated by space."
    exit -1
fi
REPO_URL="$1"
ADMIN_USER_NAME="$2"
ADMIN_USER_EMAIL="$3"
ADMIN_USER_PASSWORD="$4"


# Start installation
# -----------------------------------------------------------------------------------
cd ${APP_ROOT}
# App directory is not empty. So, the same
# needs to be cleaned first before beginning.
rm -rf ..?* .[!.]* *

git clone $REPO_URL ${APP_ROOT}/.
If_Error_Exit "Failed to clone github repo"

chown -R appusr:appusr ${APP_ROOT}

sudo -u appusr composer install --optimize-autoloader --no-interaction
If_Error_Exit "Composer installation failed"

# retrieve database user password
USER_DB_PASS=$(cat /root/mysql_app_password)

# Setting env file
# -----------------------------------------------------------------------------------
log "Setting .env file"
sudo -u appusr  cp .env.example .env


sudo -u appusr  sed -i "s|^ADMIN_USER_NAME=.*$|ADMIN_USER_NAME=\"${ADMIN_USER_NAME}\"|" .env
sudo -u appusr  sed -i "s|^ADMIN_USER_EMAIL=.*$|ADMIN_USER_EMAIL=${ADMIN_USER_EMAIL}|" .env
sudo -u appusr  sed -i "s|^ADMIN_USER_PASSWORD=.*$|ADMIN_USER_PASSWORD=${ADMIN_USER_PASSWORD}|" .env

sudo -u appusr  sed -i "s/^DB_DATABASE=.*$/DB_DATABASE=appdb/" .env
sudo -u appusr  sed -i "s/^DB_USERNAME=.*$/DB_USERNAME=dbusr/" .env
sudo -u appusr  sed -i "s/^DB_PASSWORD=.*$/DB_PASSWORD=${USER_DB_PASS}\nDB_SOCKET=\/var\/run\/mysqld\/mysqld.sock/" .env


# Running artisan commands
# -----------------------------------------------------------------------------------
log "Running artisan command"
sudo -u appusr php ${APP_ROOT}/artisan key:generate --force

sudo -u appusr php ${APP_ROOT}/artisan migrate --seed --force
sudo -u appusr php ${APP_ROOT}/artisan db:seed --class=UsersTableSeeder --force
sudo -u appusr php ${APP_ROOT}/artisan db:seed --class=IncrementalSeeder --force

sudo -u appusr php ${APP_ROOT}/artisan storage:link

# Copy Base Templates
sudo -u appusr cp -rf ${APP_ROOT}/storage/repo/templates/Serenity/* ${APP_ROOT}/resources/views/active/
sudo -u appusr cp -rf ${APP_ROOT}/storage/repo/templates/Serenity ${APP_ROOT}/resources/views/templates/


sudo -u appusr php ${APP_ROOT}/artisan cache:clear
sudo -u appusr php ${APP_ROOT}/artisan config:clear
sudo -u appusr php ${APP_ROOT}/artisan route:clear
sudo -u appusr php ${APP_ROOT}/artisan view:clear
sudo -u appusr php ${APP_ROOT}/artisan event:clear

sudo -u appusr php ${APP_ROOT}/artisan config:cache
sudo -u appusr php ${APP_ROOT}/artisan route:cache


# Scheduling Cron Task
log "Setting cron tasks"
#sudo -u appusr crontab -l > mycron
echo "* * * * * cd ${APP_ROOT} && php artisan schedule:run >> /dev/null 2>&1" >> mycron
crontab mycron
rm mycron
