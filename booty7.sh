#!/bin/bash
#
# Configures a Digital Ocean droplet for the
# installation of Laravel-based web applications.
#
# Written by Akash Mitra (akash.mitra@gmail.com)
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

# -----------------------------------------------------------------------------------
# Validate the input paramters
# -----------------------------------------------------------------------------------
PARAMS=""
HELP=0                   # show help message
REPO=0                   # GitHub source code for public repo
SWAP=1                   # Whether to add a swap space
SSH_PORT="24600"         # Default SSH Port Number
VERBOSE=0                # Show verbose information

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

# -----------------------------------------------------------------------------------
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


# -----------------------------------------------------------------------------------
# Validate the pre-conditions for running this script
# -----------------------------------------------------------------------------------
if [ `id -u` != "0" ]; then
  log "Run this script as root."
  exit -1
else
  info "Initiating Setup script version: $VERSION as root"
fi


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                          Environment related tweaks                         #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if [ $SWAP -eq 1 ]; then
    echo "Running script"
    wget -O - https://raw.githubusercontent.com/akash-mitra/booty/master/add-swap.sh | bash
fi


# -----------------------------------------------------------------------------------
# Start installations
# -----------------------------------------------------------------------------------
log "Updating system..."
apt-get --assume-yes --quiet  update                   >> /dev/null
apt-get --assume-yes --quiet  dist-upgrade             >> /dev/null
