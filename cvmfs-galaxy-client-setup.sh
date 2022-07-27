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
# Copyright (C) 2021, 2022, QCIF Ltd.
#================================================================

PROGRAM='cvmfs-galaxy-client-setup'
VERSION='1.4.0'

EXE=$(basename "$0" .sh)
EXE_EXT=$(basename "$0")

#----------------------------------------------------------------
# Constants

# Default port for the proxy cache
DEFAULT_PROXY_PORT=3128

# Default cache size in MiB (should be between 4 GiB and 50 GiB)
DEFAULT_CACHE_SIZE_MB=4096  # 4 GiB

# Minimum value allowed for --size option in MiB
MIN_CACHE_SIZE_MB=1024 # 1 GiB

#----------------

# Header inserted into generated files
PROGRAM_INFO="Created by $PROGRAM $VERSION [$(date '+%F %T %Z')]"

#----------------
# Repository specific

ORG=galaxyproject.org

STRATUM_1_HOSTS="
  cvmfs1-mel0.gvl.org.au \
  cvmfs1-ufr0.galaxyproject.eu \
  cvmfs1-tacc0.galaxyproject.org \
  cvmfs1-iu0.galaxyproject.org \
  cvmfs1-psu0.galaxyproject.org"
# Above order is significant, especially when not using the Geo API

# For dynamic configuration: the config repository

CONFIG_REPO=cvmfs-config.$ORG

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

# For static configuration: the data repository
#
# This script can also be used to statically configure a single
# repository. That is, not use the dynamic configurations from
# the CONFIG_REPO. Normally, this is not recommended.

DATA_REPO=data.$ORG

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

# Timezone database

ZONEINFO=/usr/share/zoneinfo

DEFAULT_TIMEZONE=Etc/UTC

#----------------------------------------------------------------
# Error handling

# Exit immediately if a simple command exits with a non-zero status.
# Better to abort than to continue running when something went wrong.
set -e

set -u # fail on attempts to expand undefined environment variables

#----------------------------------------------------------------
# Command line arguments
# Note: parsing does not support combining single letter options (e.g. "-vh")

CVMFS_HTTP_PROXY=
STATIC=
CVMFS_QUOTA_LIMIT_MB=$DEFAULT_CACHE_SIZE_MB
USE_GEO_API=
TIMEZONE=
QUIET=
VERBOSE=
SHOW_VERSION=
SHOW_HELP=

while [ $# -gt 0 ]
do
  case "$1" in
    -d|--direct)
      if [ -n "$CVMFS_HTTP_PROXY" ]; then
        echo "$EXE: usage error: do not use --direct with proxies" >&2
        exit 2
      fi
      CVMFS_HTTP_PROXY=DIRECT
      shift
      ;;
    -s|--static-config)
      STATIC=yes
      shift
      ;;
    -c|--cache-size)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: $1 missing value" >&2
        exit 2
      fi
      CVMFS_QUOTA_LIMIT_MB="$2"
      shift; shift
      ;;
    -g|--geo-api)
      USE_GEO_API=yes
      shift
      ;;
    -t|--timezone|--tz)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: $1 missing value" >&2
        exit 2
      fi
      TIMEZONE="$2"
      shift; shift
      ;;
    -q|--quiet)
      QUIET=yes
      shift
      ;;
    -v|--verbose)
      VERBOSE=yes
      shift
      ;;
    --version)
      SHOW_VERSION=yes
      shift
      ;;
    -h|--help)
      SHOW_HELP=yes
      shift
      ;;
    -*)
      echo "$EXE: usage error: unknown option: $1" >&2
      exit 2
      ;;
    *)
      # Argument

      if [ "$CVMFS_HTTP_PROXY" = 'DIRECT' ]; then
        echo "$EXE: usage error: do not provide proxies with --direct" >&2
        exit 2
      fi

      if echo "$1" | grep -q '^http://'; then
        echo "$EXE: usage error: expecting an address, not a URL: \"$1\"" >&2
        exit 2
      fi
      if echo "$1" | grep -q '^https://'; then
        echo "$EXE: usage error: expecting an address, not a URL: \"$1\"" >&2
        exit 2
      fi

      if echo "$1" | grep -q ':'; then
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

      shift
      ;;
  esac
done

#----------------
# Help and version options

if [ -n "$SHOW_HELP" ]; then
  cat <<EOF
Usage: $EXE_EXT [options] {proxies}
Options:
  -c | --cache-size NUM  size of cache in MiB (default: $DEFAULT_CACHE_SIZE_MB)
  -g | --geo-api         enable use of the Geo API (default: do not use it)

  -s | --static-config   configure $DATA_REPO only (not recommended)
  -d | --direct          no proxies, connect to Stratum 1 (not recommended)

  -t | --timezone TZ     set the timezone (e.g. Etc/UTC or Australia/Brisbane)

  -q | --quiet           output nothing unless an error occurs
  -v | --verbose         output extra information when running
       --version         display version information and exit
  -h | --help            display this help and exit
proxies:
  IP address of proxy servers with optional port (default: $DEFAULT_PROXY_PORT)
  e.g. 192.168.1.200 192.168.1.201:8080  # examples only: use your local proxy
EOF
  exit 0
fi

if [ -n "$SHOW_VERSION" ]; then
  echo "$PROGRAM $VERSION"
  exit 0
fi

#----------------
# Other options

if [ -n "$TIMEZONE" ]; then
  # Timezone configuration requested: check value is a valid timezone name

  if [ ! -d "$ZONEINFO" ]; then
    echo "$EXE: cannot set timezone: directory not found: $ZONEINFO" >&2
    exit 3
  fi

  if [ ! -e "$ZONEINFO/$TIMEZONE" ]; then # Note: could be file or symlink
    echo "$EXE: cannot set timezone: unknown timezone: $TIMEZONE" >&2
    exit 1
  fi
fi

if [ -n "$VERBOSE" ] && [ -n "$QUIET" ]; then
  # Verbose overrides quiet, if both are specified
  QUIET=
fi

if ! echo "$CVMFS_QUOTA_LIMIT_MB" | grep -qE '^[0-9]+$'; then
  echo "$EXE: usage error: invalid cache size: \"$CVMFS_QUOTA_LIMIT_MB\"" >&2
  exit 2
fi
if [ "$CVMFS_QUOTA_LIMIT_MB" -lt $MIN_CACHE_SIZE_MB ]; then
  echo "$EXE: usage error: cache is too small: $CVMFS_QUOTA_LIMIT_MB MiB" >&2
  exit 2
fi

if [ -z "$CVMFS_HTTP_PROXY" ]; then
  # This environment variable should either be a list of proxies (host:port)
  # separated by semicolons, or the value "DIRECT". When not using DIRECT,
  # there must be at least one proxy.
  echo "$EXE: usage error: missing proxies (-h for help)" >&2
  exit 2
fi

#----------------------------------------------------------------
# Detect tested systems

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

case "$DISTRO" in
  'CentOS Linux release 7.'* \
    | 'CentOS Linux release 8.'* \
    | 'CentOS Stream release 8' \
    | 'Rocky Linux release 8.5 (Green Obsidian)' \
    | 'Rocky Linux release 8.6 (Green Obsidian)' \
    | 'Rocky Linux release 9.0 (Blue Onyx)' \
    | 'Ubuntu 21.04' \
    | 'Ubuntu 20.04' \
    | 'Ubuntu 20.10' )
    # Tested distribution (add to above, if others have been tested)
    ;;
  *)
    echo "$EXE: warning: untested system: $DISTRO" >&2
  ;;
esac

#----------------------------------------------------------------
# Check for root privileges

if [ "$(id -u)" -ne 0 ]; then
  echo "$EXE: error: root privileges required" >&2
  exit 1
fi

#----------------------------------------------------------------
# Install CernVM-FS client

# Use LOG file to suppress apt-get messages, only show on error
# Unfortunately, "apt-get -q" and "yum install -q" still produces output.
LOG="/tmp/${PROGRAM}.$$"

#----------------
# Fedora functions

_yum_not_installed() {
  if rpm -q "$1" >/dev/null; then
    return 1 # already installed
  else
    return 0 # not installed
  fi
}

_yum_no_repo() {
  # CentOS 7 has yum 3.4.3: no --enabled option, output is "cernvm/7/x86_64..."
  # CentOS Stream 8 has yum 4.4.2: has --enabled option, output is "cernvm "
  #
  # So use old "enabled" argument instead of --enabled option and look for
  # slash or space after the repo name.

  if $YUM repolist enabled | grep -q "^$1[/ ]"; then
    return 1 # has enabled repo
  else
    return 0 # no enabled repo
  fi
}

_yum_install_repo() {
  # Install the CernVM-FS YUM repository (if needed)
  local REPO_NAME="$1"
  local URL="$2"

  if _yum_no_repo "$REPO_NAME"; then
    # Repository not installed

    _yum_install "$URL"

    if _yum_no_repo "$REPO_NAME"; then
      echo "$EXE: internal error: $URL did not install repo \"$REPO_NAME\"" >&2
      exit 3
    fi
  else
    if [ -z "$QUIET" ]; then
      echo "$EXE: repository already installed: $REPO_NAME"
    fi
  fi
}

_yum_install() {
  local PKG="$1"

  local PKG_NAME=
  if ! echo "$PKG" | grep -q /^https:/; then
    # Value is a URL: extract package name from it
    PKG_NAME=$(echo "$PKG" | sed 's/^.*\///') # remove everything up to last /
    PKG_NAME=$(echo "$PKG_NAME" | sed 's/\.rpm$//') # remove .rpm
  else
    # Assume the entire value is the package name
    PKG_NAME="$PKG"
  fi

  if ! rpm -q $PKG_NAME >/dev/null ; then
    # Not already installed

    if [ -z "$QUIET" ]; then
      echo "$EXE: $YUM install: $PKG"
    fi

    if ! $YUM install -y $PKG >$LOG 2>&1; then
      cat $LOG
      rm $LOG
      echo "$EXE: error: $YUM install: $PKG failed" >&2
      exit 1
    fi
    rm $LOG

  else
    if [ -z "$QUIET" ]; then
      echo "$EXE: package already installed: $PKG"
    fi
  fi
}

#----------------
# Debian functions

_dpkg_not_installed() {
  if dpkg-query -s "$1" >/dev/null 2>&1; then
    return 1 # already installed
  else
    return 0 # not installed
  fi
}

_dpkg_download_and_install() {
  # Download a Debian file from a URL and install it.
  local PKG_NAME="$1"
  local URL="$2"

  if _dpkg_not_installed "$PKG_NAME"; then
    # Download it

    if [ -z "$QUIET" ]; then
      echo "$EXE: downloading $URL"
    fi

    DEB_FILE="/tmp/$(basename "$URL").$$"

    if ! wget --quiet -O "$DEB_FILE" $URL; then
      rm -f "$DEB_FILE"
      echo "$EXE: error: could not download: $URL" >&2
      exit 1
    fi

    # Install it

    if [ -z "$QUIET" ]; then
      echo "$EXE: dpkg installing download file"
    fi

    if ! dpkg --install "$DEB_FILE" >$LOG 2>&1; then
      cat $LOG
      rm $LOG
      echo "$EXE: error: dpkg install failed" >&2
      exit 1
    fi

    rm -f "$DEB_FILE"

    if _dpkg_not_installed "$PKG_NAME"; then
      # The package from the URL did not install the expected package
      echo "$EXE: internal error: $URL did not install $PKG_NAME" >&2
      exit 3
    fi

  else
    if [ -z "$QUIET" ]; then
      echo "$EXE: repository already installed: $REPO_NAME"
    fi
  fi
}

_apt_get_update() {
  if [ -z "$QUIET" ]; then
    echo "$EXE: apt-get update"
  fi

  if ! apt-get update >$LOG 2>&1; then
    cat $LOG
    rm $LOG
    echo "$EXE: error: apt-get update failed" >&2
    exit 1
  fi
}

_apt_get_install() {
  local PKG="$1"

  if _dpkg_not_installed "$PKG" ; then
    # Not already installed: install it

    if [ -z "$QUIET" ]; then
      echo "$EXE: apt-get install $PKG"
    fi

    if ! apt-get install -y "$PKG" >$LOG 2>&1; then
      cat $LOG
      rm $LOG
      echo "$EXE: error: apt-get install cvmfs failed" >&2
      exit 1
    fi
    rm $LOG

  else
    if [ -z "$QUIET" ]; then
      echo "$EXE: package already installed: $PKG"
    fi
  fi
}

#----------------
# Shared functions

_set_timezone() {
  local EXTRA=
  if [ $# -gt 0 ]; then
    EXTRA="$1"
  fi

  # If the timezone is configured, this code will ALWAYS create the
  # /etc/localtime symbolic link, but will NOT CREATE the
  # /etc/timezone file if it does not exist (ONLY UPDATING it to match
  # the symbolic link, if the file already exists). Some systems have
  # both (e.g. Ubuntu 20.04) and some systems only have the symbolic
  # link (e.g. CentOS 7).

  if [ -z "$TIMEZONE" ]; then
    # User has not asked for the timezone to be configured...
    # ... but if it is not configured, try to configure it to an inferred
    # value or DEFAULT_TIMEZONE.

    # Determine if the timezone symlink needs to be created, and what
    # value to set it to.

    if [ ! -e /etc/localtime ]; then
      # Symlink missing: need to create it

      if [ ! -f /etc/timezone ]; then
        # File does not exist
        TIMEZONE=$DEFAULT_TIMEZONE
      else
        # File exists: use the value from in it
        TIMEZONE=$(cat /etc/timezone)
      fi
    fi

    if [ -n "$TIMEZONE" ]; then
      # TIMEZONE is to be configured, because the symlink is missing.

      # Check if the extracted timezone value is usable, since there
      # might have been an invalid value in the /etc/timezone file If
      # the value is not usable, the TIMEZONE is returned to being the
      # empty string: it is not an error, because the user never asked
      # for the timezone to be changeed.

      if [ -d "$ZONEINFO" ]; then
        if [ ! -e "$ZONEINFO/$TIMEZONE" ]; then # Note: file or symlink
          # Bad value: do not configure the timezone
          TIMEZONE=
        fi

      else
        # No zoneinfo directory: do not configure the timezone
        TIMEZONE=
      fi
    fi

    # Note: if the user had explicitly requested the timezone to be set,
    # the value has already been checked when the command line arguments
    # were processed.
  fi

  # Configure the timezone _only_ if TIMEZONE is set (i.e. the user explicitly
  # asked for it, or it has not been already configured).

  if [ -n "$TIMEZONE" ]; then
    # Configure timezone

    # /etc/localtime symlink (mandatory)

    if [ -z "$QUIET" ]; then
      echo "$EXE: timezone: $TIMEZONE: /etc/localtime"
    fi
    ln -s -f "$ZONEINFO/$TIMEZONE" /etc/localtime

    # /etc/timezone file (optional)

    if [ -f /etc/timezone ]; then
      # Update the file, since it already exists (i.e. never create it)

      if [ -z "$QUIET" ]; then
        echo "$EXE: timezone: $TIMEZONE: /etc/timezone"
      fi
      echo "$TIMEZONE" > /etc/timezone
    fi

    # Extra configurations (only if requested)

    if [ "$EXTRA" = DEBIAN_FRONTEND ]; then
      # Additions for Debian (needed when scrit is run inside Docker)
      DEBIAN_FRONTEND="noninteractive apt-get install -y --no-install-recommends tzdata"
      # echo "$EXE: DEBIAN_FRONTEND=$DEBIAN_FRONTEND"
    fi

  fi
}

#----------------
# Install for either Fedora or Debian based distributions

YUM=yum
if which dnf >/dev/null 2>&1; then
  YUM=dnf
fi

if which $YUM >/dev/null 2>&1; then
  # Installing for Fedora based distributions

  _set_timezone

  if _yum_not_installed 'cvmfs'; then

    # TODO: additional packages needed when inside a Docker environment

    # Get the CernVM-FS repo
    _yum_install_repo 'cernvm' \
      https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm

    _yum_install cvmfs # install CernVM-FS

  else
    if [ -z "$QUIET" ]; then
      echo "$EXE: package already installed: cvmfs"
    fi
  fi

elif which apt-get >/dev/null 2>&1; then
  # Installing for Debian based distributions

  _set_timezone DEBIAN_FRONTEND

  if _dpkg_not_installed 'cvmfs' ; then

    _apt_get_update # first update

    # These are needed when inside a Docker environment
    _apt_get_install apt-utils
    _apt_get_install python3
    _apt_get_install wget
    _apt_get_install distro-info-data
    _apt_get_install lsb-release

    # Get the CernVM-FS repo
    _dpkg_download_and_install 'cvmfs-release' \
      https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest_all.deb

    _apt_get_update # second update MUST be done after cvmfs-release-latest_all

    _apt_get_install cvmfs # install CernVM-FS

  else
    if [ -z "$QUIET" ]; then
      echo "$EXE: package already installed: cvmfs"
    fi
  fi

else
  echo "$EXE: unsupported distribution: no apt-get, yum or dnf" >&2
  exit 3
fi

#----------------------------------------------------------------
# Create directory for storing the organisation's keys

ORG_KEY_DIR="/etc/cvmfs/keys/$ORG"

if [ ! -e "$ORG_KEY_DIR" ]; then
  if ! mkdir "$ORG_KEY_DIR"; then
    echo "$EXE: error: could not create directory: $ORG_KEY_DIR" >&2
    exit 1
  fi
fi

#----------------------------------------------------------------
# Configure CernVM-FS

# Construct the value for CVMFS_SERVER_URL from Stratum 1 replica hosts

CVMFS_SERVER_URL=
for HOST in $STRATUM_1_HOSTS; do
  URL="http://$HOST/cvmfs/@fqrn@"
  if [ -z "$CVMFS_SERVER_URL" ]; then
    CVMFS_SERVER_URL=$URL
  else
    CVMFS_SERVER_URL="$CVMFS_SERVER_URL;$URL"
  fi
done

if [ -z "$STATIC" ]; then
  #----------------
  # Dynamic

  # Add public key for the config-repository

  CONFIG_REPO_KEY_FILE="$ORG_KEY_DIR/$CONFIG_REPO.pub"
  if [ -z "$QUIET" ]; then
    echo "$EXE: creating \"$CONFIG_REPO_KEY_FILE\""
  fi

  echo "$CONFIG_REPO_KEY" > "$CONFIG_REPO_KEY_FILE"
  chmod 644 "$CONFIG_REPO_KEY_FILE"

  # Create configuration for the config-repository

  FILE="/etc/cvmfs/config.d/$CONFIG_REPO.conf"
  if [ -z "$QUIET" ]; then
    echo "$EXE: creating \"$FILE\""
  fi

  cat > "$FILE" <<EOF
# $PROGRAM_INFO
# Dynamic configuration mode

CVMFS_SERVER_URL="$CVMFS_SERVER_URL"
CVMFS_PUBLIC_KEY="$CONFIG_REPO_KEY_FILE"
EOF

  # Configure CernVM-FS to use the configurations from config-repository

  FILE="/etc/cvmfs/default.d/80-$ORG-cvmfs.conf"
  if [ -z "$QUIET" ]; then
    echo "$EXE: creating \"$FILE\""
  fi

  cat > "$FILE" <<EOF
# $PROGRAM_INFO
# Dynamic configuration mode

CVMFS_CONFIG_REPOSITORY="$CONFIG_REPO"
CVMFS_DEFAULT_DOMAIN="$ORG"
EOF

  # Remove static config files, if any

  rm -f "$ORG_KEY_DIR/$DATA_REPO.pub"
  rm -f "/etc/cvmfs/domain.d/${ORG}.conf"

else
  #----------------
  # Static

  # Add public key for the repository

  REPO_PUBKEY_FILE="$ORG_KEY_DIR/$DATA_REPO.pub"
  if [ -z "$QUIET" ]; then
    echo "$EXE: creating \"$REPO_PUBKEY_FILE\""
  fi

  echo "$DATA_REPO_KEY" > "$REPO_PUBKEY_FILE"
  chmod 600 "$REPO_PUBKEY_FILE"

  # Create domain.d/org.conf

  FILE=/etc/cvmfs/domain.d/${ORG}.conf
  if [ -z "$QUIET" ]; then
    echo "$EXE: creating \"$FILE\""
  fi

  cat > "$FILE" <<EOF
# $PROGRAM_INFO
# Static configuration mode

CVMFS_SERVER_URL="$CVMFS_SERVER_URL"
CVMFS_KEYS_DIR="/etc/cvmfs/keys/$ORG"
EOF

  # Remove dynamic config files, if any

  rm -f "$ORG_KEY_DIR/$CONFIG_REPO.pub"
  rm -f "/etc/cvmfs/config.d/$CONFIG_REPO.conf"
  rm -f "/etc/cvmfs/default.d/80-$ORG-cvmfs.conf"

fi

#----------------------------------------------------------------
# Local defaults

FILE="/etc/cvmfs/default.local"

if [ -z "$QUIET" ]; then
  echo "$EXE: creating \"$FILE\""
fi

if [ -z "$USE_GEO_API" ]; then
  # This is the default, because we've found that the geographic
  # ordering is not always correct. Good or bad results are obtained,
  # depending on which Stratum 1 is queried and the particular
  # client/proxy IP address.

  GC='# '  # Comment out CVMFS_USE_GEOAPI ("no" works, but is not documented)
else
  GC=''  # Do not comment it out: i.e. set CVMFS_USE_GEOAPI to "yes"
fi

cat > "$FILE" <<EOF
# $PROGRAM_INFO

CVMFS_HTTP_PROXY=${CVMFS_HTTP_PROXY}
CVMFS_QUOTA_LIMIT=${CVMFS_QUOTA_LIMIT_MB}  # cache size in MiB (recommended: 4GB to 50GB)
${GC}CVMFS_USE_GEOAPI=yes
EOF

if [ -n "$STATIC" ]; then
  # Extra config needed for a static repository
  echo "" >> "$FILE"
  echo "CVMFS_REPOSITORIES=\"$DATA_REPO\"" >> "$FILE"
fi

#----------------------------------------------------------------
# Setup

# Check

if ! cvmfs_config chksetup >/dev/null; then
  echo "$EXE: error: bad cvmfs setup (run 'cvmfs_config chksetup')" 2>&1
  exit 1
fi

# Setup

if [ -z "$QUIET" ]; then
  echo "$EXE: running \"cvmfs_config setup\""
fi

if ! cvmfs_config setup; then
  echo "$EXE: error: cvmfs_config setup failed" 2>&1
  exit 1
fi

#----------------------------------------------------------------
# Success

if [ -z "$QUIET" ]; then
  echo "$EXE: done"
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
