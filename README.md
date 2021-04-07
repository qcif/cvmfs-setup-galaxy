# CernVM-FS setup scripts for Galaxy Project repositories

Scripts for setting up a CernVM-FS client and a CernVM-FS caching
proxy server to use the [Galaxy Project](https://galaxyproject.org)
CernVM-FS repositories.

These scripts allow the Galaxy Project CernVM-FS repositories to be
used without needing Ansible. Normally, Ansible is used by the Galaxy
Project to setup CernVM-FS, but if you don't want to use Ansible these
scripts could be used instead.

### Status

These are unofficial scripts and are not endorsed by the Galaxy
Project.

These scripts are provided on an "as is" basis.

## Requirements

The proxy setup script has been tested on:

- CentOS 7
- CentOS 8

These client setup script have been tested on:

- CentOS 7
- CentOS 8
- Ubuntu 20.04
- Ubuntu 18.04
- Ubuntu 16.04


## Usage

CernVM-FS repositories are deployed as a single Stratum 0 master
server, where files in the repository are modified, and Stratum 1
replicas.

Typically, an organisation should have a _proxy_ server, which
downloads files from the Stratum 1 servers. Hosts using the repository
are the _clients_, and they should download files from the local
_proxy_.

The two scripts are for deploying _proxies_ and _clients_. Run the
scripts with a `--help` option to see the available options.

### Proxy

To setup a Galaxy Project CernVM-FS proxy, run:

```sh
$ sudo ./cvmfs-galaxy-proxy-setup.sh CLIENT_HOSTS
```

The client hosts indicate which hosts can connect to the proxy. It
must include all the machines that will be clients, otherwise they
won't be able to use the proxy. Provide one or more CIDR values
(e.g. "192.168.0.0/16 172.16.0.0/12 203.101.224.0/20").

The script will:

- install the Squid proxy server
- configure the Squid proxy server
- start and enable the Squid proxy server

### Port number

The `--port` option can be used to specify which port number the Squid
proxy will be listening on. By default, port 3128 is used.

## Client

To setup a Galaxy Project CernVM-FS client, run:

```sh
sudo ./cvmfs-galaxy-client-setup.sh PROXY_ADDRESSES
```

The proxy addresses are one or more proxy servers to use (IP addresses
or hostnames). An organisation may have multiple proxy servers for
redundancy.

The proxy addresses can include an optional port number following a
colon (e.g. "10.10.123.123:8080"). If omitted, it defaults to port
3128.

The script will:

- install the CernVM-FS client software
- create configuration files for the Galaxy Project CernVM-FS repositories

The repositories can then be accessed in the normal manner:

```sh
$ ls /cvmfs/data.galaxyproject.org
$ ls /cvmfs/main.galaxyproject.org
$ ls /cvmfs/singularity.galaxyproject.org
```

```sh
cvmfs_config stat -v
```

The available respository names can be discovered by listing
the available public keys under the
_/cvmfs/cvmfs-config.galaxyproject.org/etc/cvmfs/keys/galaxyproject.org/_
directory.

### Cache size

Use the `--cache-size` option to specify the size of the client's
cache in MiB.

The default is 4 GiB.  The cache size should bes between 4 GiB and 50
GiB (i.e. between 4096 and 51200 MiB), but it depends on how clients
will use the repositories and the available storage on the client
host.

### Dynamic configuration

By default, it is setup to use dynamic configurations from the
_cvmfs-config.galaxyproject.org_ repository. That automatically gives
access to all of the Galaxy Project repositories. Also, the
configuration will be automatically updated if it is updated by the
Galaxy Project.

Alternatively, the `--static-config` option can be used to configure a
single repository. This option is needed to manually add additional
CernVM-FS repositories from different organisations, since the dynamic
configuration can only support one organisation's repositories.

## Common options

### Verbose mode

When run with `--verbose`, the scripts will print out what they are
doing.  This includes indicating which configuration files are created
or modified.

## Notes

- It is possible to install both proxy and client on the same host.
  But that is not recommended for production use.

- It is possible to setup a client to not use a proxy: for it to
  contact the Stratum 1 replicas directly. But that is not
  recommended for production use.

## Acknowledgements

This work is supported by the Australian BioCommons which is enabled
by NCRIS via Bioplatforms Australia funding.

## See also

- [usegalaxy.org Reference data](https://galaxyproject.org/admin/reference-data-repo/) - documentation on the Galaxy Project's CVMFS repositories

- [Reference Data with CVMFS](https://training.galaxyproject.org/training-material/topics/admin/tutorials/cvmfs/tutorial.html) - Galaxy Project's tutorial for using CVMFS with Ansible

- [Ansible scripts for CVMFS](https://github.com/galaxyproject/ansible-cvmfs) - from the Galaxy Project
