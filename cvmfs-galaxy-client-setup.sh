#!/bin/sh
#
# Configure a host as a client to the Galaxy CernVM-FS repositories.
#
# USAGE
#
#     sudo ./cvmfs-galaxy-client-setup.sh -v <PROXY_ADDRESS>
#
# The above may take about 2 minutes to run. After which the Galaxy
# CernVM-FS repositories can be accessed. For example,
#
#     ls /cvmfs/data.galaxyproject.org
#
# The initial access may take about 5 seconds on CentOS 7, but will be
# faster after that. With autofs, the directory won't appear under /cvmfs
# until it has been accessed.
#
# DESCRIPTION
#
# Install CernVM-FS client software and configure it to use the
# configurations from the "cvmfs-config.galaxyproject.org" repository
# for the Galaxy repositories.
#
# Copyright (C) 2021, QCIF Ltd.
#================================================================

PROGRAM='cvmfs-galaxy-client-setup'
VERSION='1.0.0'

EXE=$(basename "$0" .sh)

#----------------------------------------------------------------
# Constants

# Default port for the proxy cache
DEFAULT_PROXY_PORT=3128

# Default cache size in MiB (should be between 4 GiB and 50 GiB)
DEFAULT_CACHE_SIZE_MB=4096  # 4 GiB

# Minimum value allowed for --size option in MiB
MIN_CACHE_SIZE_MB=1024 # 1 GiB

#----------------

ORG=galaxyproject.org

CONFIG_REPO=cvmfs-config.galaxyproject.org

CONFIG_REPO_KEY='-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuJZTWTY3/dBfspFKifv8
TWuuT2Zzoo1cAskKpKu5gsUAyDFbZfYBEy91qbLPC3TuUm2zdPNsjCQbbq1Liufk
uNPZJ8Ubn5PR6kndwrdD13NVHZpXVml1+ooTSF5CL3x/KUkYiyRz94sAr9trVoSx
THW2buV7ADUYivX7ofCvBu5T6YngbPZNIxDB4mh7cEal/UDtxV683A/5RL4wIYvt
S5SVemmu6Yb8GkGwLGmMVLYXutuaHdMFyKzWm+qFlG5JRz4okUWERvtJ2QAJPOzL
mAG1ceyBFowj/r3iJTa+Jcif2uAmZxg+cHkZG5KzATykF82UH1ojUzREMMDcPJi2
dQIDAQAB
-----END PUBLIC KEY-----
'

STRATUM_ONE_SERVERS="
  cvmfs1-psu0.galaxyproject.org \
  cvmfs1-iu0.galaxyproject.org \
  cvmfs1-tacc0.galaxyproject.org \
  cvmfs1-ufr0.galaxyproject.eu \
  cvmfs1-mel0.gvl.org.au"

#----------------
# For static configuration
#
# This script can also be used to statically configure a single
# repository. That is, not use the dynamic configurations from
# cvmfs-config.galaxyproject.org.
#
# Normally, this is not recommended.

DATA_REPO='data.galaxyproject.org'

DATA_REPO_KEY='-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5LHQuKWzcX5iBbCGsXGt
6CRi9+a9cKZG4UlX/lJukEJ+3dSxVDWJs88PSdLk+E25494oU56hB8YeVq+W8AQE
3LWx2K2ruRjEAI2o8sRgs/IbafjZ7cBuERzqj3Tn5qUIBFoKUMWMSIiWTQe2Sfnj
GzfDoswr5TTk7aH/FIXUjLnLGGCOzPtUC244IhHARzu86bWYxQJUw0/kZl5wVGcH
maSgr39h1xPst0Vx1keJ95AH0wqxPbCcyBGtF1L6HQlLidmoIDqcCQpLsGJJEoOs
NVNhhcb66OJHah5ppI1N3cZehdaKyr1XcF9eedwLFTvuiwTn6qMmttT/tHX7rcxT
owIDAQAB
-----END PUBLIC KEY-----
'

#----------------------------------------------------------------

#TIMESTAMP=$(date '+%F %T %Z')s
#PROGRAM_INFO="Created by $PROGRAM $VERSION [$TIMESTAMP]"

#----------------------------------------------------------------
# Error handling

# Exit immediately if a simple command exits with a non-zero status.
# Better to abort than to continue running when something went wrong.
set -e

#----------------------------------------------------------------
# Command line arguments

CVMFS_HTTP_PROXY=
CVMFS_QUOTA_LIMIT_MB=$DEFAULT_CACHE_SIZE_MB
STATIC=
VERBOSE=
SHOW_VERSION=
SHOW_HELP=

while [ $# -gt 0 ]
do
  case "$1" in
    -c|--cache-size)
      CVMFS_QUOTA_LIMIT_MB="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--direct)
      CVMFS_HTTP_PROXY=DIRECT
      shift # past argument
      ;;
    -s|--static-config)
      STATIC=yes
      shift;
      ;;
    -v|--verbose)
      VERBOSE=yes
      shift # past argument
      ;;
    --version)
      SHOW_VERSION=yes
      shift # past argument
      ;;
    -h|--help)
      SHOW_HELP=yes
      shift # past argument
      ;;
    *)
      # unknown option
      if echo "$1" | grep ^- >/dev/null; then
        echo "$EXE: usage error: unknown option: \"$1\"" >&2
        exit 2
      else
        # Use as a proxy address

        if echo "$1" | grep '^http://' >/dev/null; then
          echo "$EXE: usage error: expecting an address, not a URL: \"$1\"" >&2
          exit 2
        fi
        if echo "$1" | grep '^https://' >/dev/null; then
          echo "$EXE: usage error: expecting an address, not a URL: \"$1\"" >&2
          exit 2
        fi

        if echo "$1" | grep ':' >/dev/null; then
          # Value has a port number
          P="$1"
        else
          # Use default port number
          P="$1:$DEFAULT_PROXY_PORT"
        fi

        if [ -z "$CVMFS_HTTP_PROXY" ]; then
          CVMFS_HTTP_PROXY="$P"
        else
          CVMFS_HTTP_PROXY="$CVMFS_HTTP_PROXY;$P"
        fi
      fi
      shift # past argument
      ;;
  esac
done

if [ -n "$SHOW_HELP" ]; then
  cat <<EOF
Usage: $EXE [options] {proxies}
Options:
  -c | --cache-size NUM  size of cache in MiB (default: $DEFAULT_CACHE_SIZE_MB)
  -s | --static-config   configure $DATA_REPO only (not recommended)
  -d | --direct          no proxies, connect to Stratum 1 (not recommended)
  -v | --verbose         output extra information when running
       --version         display version information and exit
  -h | --help            display this help and exit
proxies:
  IP address of proxy servers with optional port (default: $DEFAULT_PROXY_PORT)
  e.g. 192.168.1.200 192.168.1.201:8080
EOF
  exit 0
fi

if [ -n "$SHOW_VERSION" ]; then
  echo "$PROGRAM $VERSION"
  exit 0
fi

if ! echo "$CVMFS_QUOTA_LIMIT_MB" | grep -E '^[0-9]+$' >/dev/null ; then
  echo "$EXE: usage error: invalid number: \"$CVMFS_QUOTA_LIMIT_MB\"" >&2
  exit 2
fi
if [ "$CVMFS_QUOTA_LIMIT_MB" -lt $MIN_CACHE_SIZE_MB ]; then
  echo "$EXE: usage error: cache is too small: $CVMFS_QUOTA_LIMIT_MB MiB" >&2
  exit 2
fi

if [ -z "$CVMFS_HTTP_PROXY" ]; then
  echo "$EXE: usage error: missing proxies (-h for help)" >&2
  exit 2
fi

#----------------------------------------------------------------
# Detect Linux distribution

DISTRO=unknown
if [ -f '/etc/system-release' ]; then
  DISTRO=$(head -1 /etc/system-release)
elif which lsb_release >/dev/null 2>&1; then
  DISTRO="$(lsb_release --id --short) $(lsb_release --release --short)"
fi

if echo "$DISTRO" | grep '^CentOS Linux release 7' > /dev/null; then
  :
elif echo "$DISTRO" | grep '^CentOS Linux release 8' > /dev/null; then
  :
elif [ "$DISTRO" = 'Ubuntu 20.04' ]; then
  :
elif [ "$DISTRO" = 'Ubuntu 18.04' ]; then
  :
elif [ "$DISTRO" = 'Ubuntu 16.04' ]; then
  :
else
  # Add additional elif-statements for tested distributions
  echo "$EXE: error: unsupported system/distribution: $DISTRO" >&2
  exit 1
fi

#----------------------------------------------------------------
# Check for root privileges

if [ "$(id -u)" -ne 0 ]; then
  echo "$EXE: error: root privileges required" >&2
  exit 1
fi

#----------------------------------------------------------------
# Install CernVM-FS client software

if echo "$DISTRO" | grep '^CentOS' >/dev/null; then
  # Installing for CentOS

  if ! rpm -q 'cvmfs' >/dev/null; then
    EXPECTING='/etc/yum.repos.d/cernvm.repo'
    if [ ! -e "$EXPECTING" ]; then
      # Setting up CernVM-FS YUM repository

      if [ -n "$VERBOSE" ]; then
        echo "$EXE: yum installing \"cvmfs-release-latest\" package"
      fi

      if ! yum install -y -q \
           https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm;
      then
        echo "$EXE: error: yum install failed" >&2
        exit 1
      fi

      if [ ! -e "$EXPECTING" ]; then
        # The expected file was not installed.
        # This means the above test for determining if the YUM repository
        # has been installed or not needs to be changed.
        echo "$EXE: warning: file not found: $EXPECTING" >&2
      fi
    fi

    # Installing cvmfs package

    if [ -n "$VERBOSE" ]; then
      echo "$EXE: yum installing \"cvmfs\" package"
    fi

    # Use LOG file to suppress GPG key messages, only show on error
    LOG="/tmp/${PROGRAM}.$$"
    if ! yum install -y -q cvmfs 2>$LOG; then
      cat $LOG
      rm $LOG
      echo "$EXE: error: yum install failed" >&2
      exit 1
    fi
    rm $LOG
  fi

elif echo "$DISTRO" | grep '^Ubuntu' >/dev/null; then
  # Installing for Ubuntu

  # TODO: check if it is already installed

  URL=https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest_all.deb

  if [ -n "$VERBOSE" ]; then
    echo "$EXE: downloading $URL"
  fi

  DEB_FILE=/tmp/cvmfs-release-latest_all.deb

  if ! wget --quiet -O "$DEB_FILE" $URL; then
    echo "$EXE: error: could not download: $URL" >&2
    exit 1
  fi

  if [ -n "$VERBOSE" ]; then
    echo "$EXE: dpkg installing $DEB_FILE"
  fi

  # Use LOG file to suppress apt-get messages, only show on error
  # Unfortunately, "apt-get -q" still produces output.
  LOG="/tmp/${PROGRAM}.$$"

  if ! dpkg --install "$DEB_FILE" >$LOG 2>&1; then
    cat $LOG
    rm $LOG
    echo "$EXE: error: dpkg install failed" >&2
    exit 1
  fi

  rm "$DEB_FILE"

  if [ -n "$VERBOSE" ]; then
    echo "$EXE: apt-get update"
  fi

  if ! apt-get update >$LOG 2>&1; then
    cat $LOG
    rm $LOG
    echo "$EXE: error: apt-get update failed" >&2
    exit 1
  fi

  if [ -n "$VERBOSE" ]; then
    echo "$EXE: apt-get install cvmfs"
  fi

  if ! apt-get install -y cvmfs >$LOG 2>&1; then
    cat $LOG
    rm $LOG
    echo "$EXE: error: apt-get install cvmfs failed" >&2
    exit 1
  fi
  rm $LOG
else
  echo "$EXE: internal error: DISTRO=$DISTRO" >&2
  exit 3
fi

#----------------------------------------------------------------
# Create key directory for organisation

ORG_KEY_DIR="/etc/cvmfs/keys/$ORG"

if [ ! -e "$ORG_KEY_DIR" ]; then
  # Create the keys/org directory
  if ! mkdir /etc/cvmfs/keys/$ORG; then
    echo "$EXE: error: could not create directory: $ORG_KEY_DIR" >&2
    exit 1
  fi
fi

#----------------------------------------------------------------

if [ -z "$STATIC" ]; then
  #----------------
  # Dynamic

  # Add public key for the config-repository

  CONFIG_REPO_KEY_FILE="$ORG_KEY_DIR/$CONFIG_REPO.pub"
  if [ -n "$VERBOSE" ]; then
    echo "$EXE: creating \"$CONFIG_REPO_KEY_FILE\""
  fi

  echo "$CONFIG_REPO_KEY" | tee "$CONFIG_REPO_KEY_FILE" >/dev/null

  # Create configuration for the config-repository

  FILE="/etc/cvmfs/config.d/$CONFIG_REPO.conf"
  if [ -n "$VERBOSE" ]; then
    echo "$EXE: creating \"$FILE\""
  fi

  # Build CVMFS_SERVER_URL value from Stratum 1 replica servers

  CVMFS_SERVER_URL=
  for SERVER in $STRATUM_ONE_SERVERS; do
    URL="http://$SERVER/cvmfs/@fqrn@"
    if [ -z "$CVMFS_SERVER_URL" ]; then
      CVMFS_SERVER_URL=$URL
    else
      CVMFS_SERVER_URL="$CVMFS_SERVER_URL;$URL"
    fi
  done

  tee "$FILE" >/dev/null <<EOF
# $EXE_INFO

CVMFS_SERVER_URL="$CVMFS_SERVER_URL"
CVMFS_PUBLIC_KEY="$CONFIG_REPO_KEY_FILE"
EOF

  # Configure CernVM-FS to use the configurations from the config-repository

  FILE="/etc/cvmfs/default.d/80-$ORG-cvmfs.conf"
  if [ -n "$VERBOSE" ]; then
    echo "$EXE: creating \"$FILE\""
  fi

  tee "$FILE" >/dev/null <<EOF
# $EXE_INFO

CVMFS_CONFIG_REPOSITORY="$CONFIG_REPO"
CVMFS_DEFAULT_DOMAIN="$ORG"
EOF

else
  #----------------
  # Static

  FILE="$ORG_KEY_DIR/$DATA_REPO.pub"
  if [ -n "$VERBOSE" ]; then
    echo "$EXE: creating \"$FILE\""
  fi

  echo "$DATA_REPO_KEY" |tee "$FILE" >/dev/null

  # Create domain.d/org.conf

  FILE=/etc/cvmfs/domain.d/${ORG}.conf
  if [ -n "$VERBOSE" ]; then
    echo "$EXE: creating \"$FILE\""
  fi

  sudo tee "$FILE" >/dev/null <<EOF
# $EXE_INFO

CVMFS_SERVER_URL="$CVMFS_SERVER_URL"
CVMFS_KEYS_DIR="/etc/cvmfs/keys/$ORG"
EOF

fi

#----------------------------------------------------------------
# Local defaults

FILE="/etc/cvmfs/default.local"

if [ -n "$VERBOSE" ]; then
  echo "$EXE: creating \"$FILE\""
fi

tee "$FILE" >/dev/null <<EOF
# $EXE_INFO

CVMFS_HTTP_PROXY=${CVMFS_HTTP_PROXY=DIRECT}
CVMFS_QUOTA_LIMIT=${CVMFS_QUOTA_LIMIT_MB}  # cache size in MiB (recommended: 4GB to 50GB)
CVMFS_USE_GEOAPI=yes  # sort server list by geographic distance from client
EOF

if [ -n "$STATIC" ]; then
  # Extra config for static repository
  echo "" | tee -a "$FILE" >/dev/null
  echo "CVMFS_REPOSITORIES=\"$DATA_REPO\"" | tee -a "$FILE" >/dev/null
fi

#----------------------------------------------------------------
# Setup

# Check

if ! cvmfs_config chksetup >/dev/null; then
  echo "$EXE: error: bad cvmfs setup (run 'cvmfs_config chksetup')" 2>&1
  exit 1
fi

# Setup

if [ -n "$VERBOSE" ]; then
  echo "$EXE: running \"cvmfs_config setup\""
fi

if ! cvmfs_config setup; then
  echo "$EXE: error: cvmfs_config setup failed" 2>&1
  exit 1
fi

#----------------------------------------------------------------
# Success

if [ -n "$VERBOSE" ]; then
  echo "$EXE: ok"
fi

exit 0

# To reload a repository:
#
#     cvmfs_config reload <repository-name>

# Available repositories (as of 2021-02-22):
#
# cvmfs-config.galaxyproject.org
# data.galaxyproject.org
# main.galaxyproject.org
# sandbox.galaxyproject.org
# singularity.galaxyproject.org
# test.galaxyproject.org
# usegalaxy.galaxyproject.org

#EOF
