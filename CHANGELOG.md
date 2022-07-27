# Changelog

## 1.4.0

- Added support for Rocky Linux 8.6.
- Added support for Rocky Linux 9.0.

## 1.3.0

- Added support for Rocky Linux 8.5.

## 1.2.0

- Disable use of Geo API by default and added --geo-api option to enable it.
- Added optional timezone configuration (needed for Docker).
- Added packages needed when script is run inside Docker with Debian/Ubuntu.
- Create /etc/localtime with a default timezone if it does not already exist.

## 1.1.1

- Updated code for consistency with cvmfs-setup-example scripts.

## 1.1.0

- Added --quiet option and changed default behaviour of --verbose.

## 1.0.0

- Initial release.
