#!/bin/bash
#
# This script performs inital configuration for mysql
# similar to what is performed by mysql_secure_installation.
#
# In fact, the operations are inspired from the original
# mysql_secure_installation script located here:
# https://github.com/twitter-forks/mysql/blob/master/scripts/mysql_secure_installation.sh
#
#
#
# Written by Akash Mitra (Twitter @aksmtr)
# Written for Maria DB 10.4 installed in Ubuntu 18.04 LTS
#
# version 0.1
#

# Delete anonymous users - if any.
mysql -e "DELETE FROM mysql.user WHERE User=''"

# Delete non-local connections for root accounts
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"

# Delete any Test database - if present
mysql -e "DROP DATABASE IF EXISTS test";
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'";

# Note: The below command generates a alpha-numeric random
# password of 27 characters (4 groups of 6 chars separated by dash)
#
# Example Generated password:  22B4Ub-HEyKyL-K5FvtA-eoVFa1
#
MYSQL_ROOT_PWD=`openssl rand -base64 50 | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -4 | paste -sd "-" -`
MYSQL_APP_PWD=`openssl rand -base64 50 | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -4 | paste -sd "-" -`

# Create a new application database (appdb)
mysql -e "CREATE DATABASE appdb DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_bin";

# Create a new application database user (dbusr)
# Note - This user can only access from the localhost.
mysql -e "GRANT ALL PRIVILEGES ON appdb.* to dbusr@'localhost' IDENTIFIED BY '"${MYSQL_APP_PWD}"'";
echo ${MYSQL_APP_PWD} > /root/mysql_app_password
chmod 600 /root/mysql_app_password

# Change the root password & store it in root's home directory
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '"${MYSQL_ROOT_PWD}"'";
echo ${MYSQL_ROOT_PWD} > /root/mysql_root_password
chmod 600 /root/mysql_root_password
