#!/bin/sh
#
# Configure host as a caching proxy to the Galaxy CernVM-FS repositories.
#
# USAGE
#
#     sudo ./cvmfs-galaxy-proxy-setup.sh -v <CLIENT_HOSTS>
#
# Where CLIENT_HOSTS are the addresses of the client hosts that will
# be permitted to access the proxy. CIDR addresses allowed
# (e.g. 10.0.0.0/24).
#
# The above may take about 40 seconds to run.
#
# DESCRIPTION
#
# Install a Squid Proxy server for accessing the Galaxy CernVM-FS
# repositories.
#
# Copyright (C) 2021, QCIF Ltd.
#================================================================

PROGRAM='cvmfs-galaxy-proxy-setup'
VERSION='1.1.0'

EXE=$(basename "$0" .sh)
EXE_EXT=$(basename "$0")

#----------------------------------------------------------------
# Constants

#----------------

DEFAULT_PROXY_PORT=3128

DEFAULT_DISK_CACHE_SIZE_MB=5120
DEFAULT_MEM_CACHE_SIZE_MB=256

MIN_DISK_CACHE_SIZE_MB=128
MIN_MEM_CACHE_SIZE_MB=10

#----------------
# The Stratum 1 servers
#
# Values were obtained from
# <https://galaxyproject.org/admin/reference-data-repo/>

STRATUM_ONE_SERVERS="
  cvmfs1-psu0.galaxyproject.org \
  cvmfs1-iu0.galaxyproject.org \
  cvmfs1-tacc0.galaxyproject.org \
  cvmfs1-ufr0.galaxyproject.eu \
  cvmfs1-mel0.gvl.org.au"

#----------------------------------------------------------------

TIMESTAMP=$(date '+%F %T %Z')
PROGRAM_INFO="Created by $PROGRAM $VERSION [$TIMESTAMP]"

#----------------------------------------------------------------
# Error handling

# Exit immediately if a simple command exits with a non-zero status.
# Better to abort than to continue running when something went wrong.
set -e

#----------------------------------------------------------------
# Command line arguments

CLIENTS=
PROXY_PORT=$DEFAULT_PROXY_PORT
DISK_CACHE_SIZE_MB=$DEFAULT_DISK_CACHE_SIZE_MB
MEM_CACHE_SIZE_MB=$DEFAULT_MEM_CACHE_SIZE_MB
QUIET=
VERBOSE=
SHOW_VERSION=
SHOW_HELP=

while [ $# -gt 0 ]
do
  case "$1" in
    -p|--port)
      PROXY_PORT="$2"
      shift
      shift
      ;;
    -d|--disk-cache)
      DISK_CACHE_SIZE_MB="$2"
      shift; shift
      ;;
    -m|--mem-cache)
      MEM_CACHE_SIZE_MB="$2"
      shift; shift
      ;;
    -q|--quiet)
      QUIET=yes
      shift # past argument
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
    *)    # unknown option
      if echo "$1" | grep ^- >/dev/null; then
        echo "$EXE: usage error: unknown option: \"$1\"" >&2
        exit 2
      else
        # Use as a client address

        if echo "$1" | grep '^http://' >/dev/null; then
          echo "$EXE: usage error: expecting an address, not a URL: \"$1\"" >&2
          exit 2
        fi
        if echo "$1" | grep '^https://' >/dev/null; then
          echo "$EXE: usage error: expecting an address, not a URL: \"$1\"" >&2
          exit 2
        fi

        CLIENTS="$CLIENTS $1"
      fi
      shift # past argument
      ;;
  esac
done

#----------------
# Help and version options

if [ -n "$SHOW_HELP" ]; then
  if ip addr | grep 203.101.239.255 >/dev/null ; then
    EXAMPLE_CLIENTS="203.101.224.0/20" # QRIScloud specific example
  else
    EXAMPLE_CLIENTS="192.168.0.0/16 172.16.0.0/12"
  fi

  cat <<EOF
Usage: $EXE_EXT [options] {allowed-clients}
Options:
  -p | --port NUM       proxy port (default: $DEFAULT_PROXY_PORT)
  -d | --disk-cache NUM size of disk cache in MiB (default: $DEFAULT_DISK_CACHE_SIZE_MB)
  -m | --mem-cache NUM  size of memory cache in MiB (default: $DEFAULT_MEM_CACHE_SIZE_MB)
  -q | --quiet          output nothing unless an error occurs
  -v | --verbose        output extra information when running
       --version        display version information and exit
  -h | --help           display this help and exit
allowed-clients:
  CIDR addresses of clients allowed to use this proxy server
  e.g. $EXAMPLE_CLIENTS
EOF
  exit 0
fi

if [ -n "$SHOW_VERSION" ]; then
  echo "$PROGRAM $VERSION"
  exit 0
fi

#----------------
# Other options

if [ -n "$VERBOSE" ] && [ -n "$QUIET" ]; then
  # Verbose overrides quiet, if both are specified
  QUIET=
fi

if ! echo "$PROXY_PORT" | grep -E '^[0-9]+$' >/dev/null ; then
  echo "$EXE: usage error: invalid port number: \"$PROXY_PORT\"" >&2
  exit 2
fi
if [ "$PROXY_PORT" -lt 1 ] || [ "$PROXY_PORT" -gt 65535 ]; then
  echo "$EXE: usage error:  port number out of range: $PROXY_PORT" >&2
  exit 2
fi

if ! echo "$DISK_CACHE_SIZE_MB" | grep -E '^[0-9]+$' >/dev/null ; then
  echo "$EXE: usage error: disk cache: invalid number: \"$DISK_CACHE_SIZE_MB\"" >&2
  exit 2
fi
if [ "$DISK_CACHE_SIZE_MB" -lt $MIN_DISK_CACHE_SIZE_MB ]; then
  echo "$EXE: usage error: disk cache is too small: $DISK_CACHE_SIZE_MB MiB" >&2
  exit 2
fi

if ! echo "$MEM_CACHE_SIZE_MB" | grep -E '^[0-9]+$' >/dev/null ; then
  echo "$EXE: usage error: memory cache: invalid number: \"$MEM_CACHE_SIZE_MB\"" >&2
  exit 2
fi
if [ "$MEM_CACHE_SIZE_MB" -lt $MIN_MEM_CACHE_SIZE_MB ]; then
  echo "$EXE: usage error: memory cache is too small: $MEM_CACHE_SIZE_MB MiB" >&2
  exit 2
fi

if [ -z "$CLIENTS" ]; then
  echo "$EXE: usage error: missing client hosts (-h for help)" >&2
  exit 2
fi

#----------------------------------------------------------------
# Detect tested systems

DISTRO=unknown
if [ -f '/etc/system-release' ]; then
  # Fedora based
  DISTRO=$(head -1 /etc/system-release)
elif which lsb_release >/dev/null 2>&1; then
  # Debian based
  DISTRO="$(lsb_release --id --short) $(lsb_release --release --short)"
elif which uname >/dev/null 2>&1; then
  # Other
  DISTRO="$(uname -s) $(uname -r)"
else
  DISTRO=unknown
fi

if echo "$DISTRO" | grep '^CentOS Linux release 7' > /dev/null; then
  :
elif echo "$DISTRO" | grep '^CentOS Linux release 8' > /dev/null; then
  :
elif echo "$DISTRO" | grep '^CentOS Stream release 8' > /dev/null; then
  :
elif [ "$DISTRO" = 'Ubuntu 20.04' ]; then
  :
elif [ "$DISTRO" = 'Ubuntu 18.04' ]; then
  :
elif [ "$DISTRO" = 'Ubuntu 16.04' ]; then
  :
else
  # Add additional elif-statements for tested systems
  echo "$EXE: warning: untested system: $DISTRO" >&2
fi

#----------------------------------------------------------------
# Check for root privileges

if [ "$(id -u)" -ne 0 ]; then
  echo "$EXE: error: root privileges required" >&2
  exit 1
fi

#----------------------------------------------------------------
# Install Squid proxy server

# Use LOG file to suppress apt-get messages, only show on error
# Unfortunately, "apt-get -q" and "yum install -q" still produces output.
LOG="/tmp/${PROGRAM}.$$"

_yum_install() {
  PKG="$1"

  if ! rpm -q $PKG >/dev/null ; then
    # Not already installed

    if [ -z "$QUIET" ]; then
      echo "$EXE: yum install: $PKG"
    fi

    if ! yum install -y $PKG >$LOG 2>&1; then
      cat $LOG
      rm $LOG
      echo "$EXE: error: yum install: $PKG failed" >&2
      exit 1
    fi
    if [ -n "$VERBOSE" ]; then
      cat $LOG
    fi
    rm $LOG

  else
    if [ -z "$QUIET" ]; then
      echo "$EXE: package already installed: $PKG"
    fi
  fi
}

#----------------

if which yum >/dev/null; then
  # Installing for Fedora based systems

  _yum_install squid

elif which apt-get >/dev/null; then
  # Installing for Debian based systems

  if [ -z "$QUIET" ]; then
    echo "$EXE: apt-get update"
  fi

  if ! apt-get update >$LOG 2>&1; then
    cat $LOG
    rm $LOG
    echo "$EXE: error: apt-get update: failed" >&2
    exit 1
  fi

  # Install Squid proxy server

  if [ -z "$QUIET" ]; then
    echo "$EXE: apt-get install: squid"
  fi

  if ! apt-get install -y squid >$LOG 2>&1; then
    cat $LOG
    rm $LOG
    echo "$EXE: error: apt-get install: squid failed" >&2
    exit 1
  fi
  rm $LOG

else
  echo "$EXE: unsupported system: no yum or apt-get" >&2
  exit 3
fi

#----------------------------------------------------------------
# Configure Squid

SQUID_CONF='/etc/squid/squid.conf'

if [ -z "$QUIET" ]; then
  echo "$EXE: creating \"$SQUID_CONF\""
fi

tee "$SQUID_CONF" >/dev/null <<EOF
# Squid proxy configuration
# $PROGRAM_INFO

# Squid port
http_port ${PROXY_PORT}

#----------------
# Access control

# Addresses (CIDR) allowed to use this proxy (i.e. the client hosts)
EOF

for C in $CLIENTS; do
  echo "acl client_nodes src $C" | tee -a "$SQUID_CONF" >/dev/null
done

tee -a "$SQUID_CONF" >/dev/null <<EOF

# Destinations the proxy is allowed to access (i.e. the Stratum 1 replicas)
#   Can be "dst IP_ADDR", "dstdomain .EXAMPLE.ORG" or "dstdom_regex REGEX"

EOF

for S1 in $STRATUM_ONE_SERVERS; do
  echo "acl stratum_ones dstdomain $S1" | tee -a "$SQUID_CONF" >/dev/null
done

tee -a "$SQUID_CONF" >/dev/null <<EOF

# Deny access to all except the stratum_ones ACL.
http_access deny !stratum_ones

# Allow from local client hosts and localhost
http_access allow client_nodes
http_access allow localhost

# Finally, deny all others
http_access deny all

#----------------

minimum_expiry_time 0
maximum_object_size 1024 MB

cache_mem ${MEM_CACHE_SIZE_MB} MB
maximum_object_size_in_memory 16 MB

# Disk cache
# cache_dir TYPE DIRECTORY-NAME FS-SPECIFIC-DATA [OPTIONS]
# cache_dir ufs  DIRECTORY-NAME Mbytes L1 L2     [OPTIONS]
cache_dir ufs /var/spool/squid ${DISK_CACHE_SIZE_MB} 16 256
EOF

#----------------------------------------------------------------
# Check the Squid configuration

if ! squid -k parse >/dev/null 2>&1; then
  echo "$EXE: internal error: squid config is incorrect" >&2
  exit 1
fi

#----------------------------------------------------------------
# Start Squid and enable it to start when the host boots

if [ -z "$QUIET" ]; then
  echo "$EXE: restarting and enabling squid.service"
fi

# Note: in case it was already running, use restart instead of start.
if ! systemctl restart squid.service; then
  echo "$EXE: error: squid start failed" >&2
  exit 1
fi

if ! systemctl enable squid.service 2>/dev/null; then
  echo "$EXE: error: squid enable failed" >&2
  exit 1
fi

#----------------------------------------------------------------
# Success

if [ -z "$QUIET" ]; then
  echo "$EXE: ok"
fi

#EOF
