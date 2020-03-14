#!/bin/bash
#
# Adds Swap Space.
# Written by Akash Mitra (Twitter @aksmtr)
# Written for Ubuntu 18.04 LTS.
# -----------------------------------------------------------------------------------

# create 512M swap space
fallocate -l 1G /swapfile
chmod 600 /swapfile

# denote the file as swap space
mkswap /swapfile

# activate the swap
swapon /swapfile

# Set swapiness
# This is a value between 0 and 100 that represents a percentage.
# With values close to zero, the kernel will not swap data to the
# disk unless absolutely necessary.
sysctl vm.swappiness=10

# how much the system will choose to cache inode and dentry information over other data.
# Higher value means system removes inode information from the cache too quickly.
sysctl vm.vfs_cache_pressure=50

# make the swap file permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf