# CernVM-FS setup scripts for the Galaxy Project repositories

Scripts for setting up a CernVM-FS client and a CernVM-FS caching
proxy server to use the Galaxy Project's CernVM-FS repositories.

These scripts allow the Galaxy Project's CernVM-FS repositories to be
used without needing Ansible. Normally, Ansible is used by the Galaxy
Project, but if you don't want to use Ansible these scripts could be
used instead.

### Status

These are unofficial scripts.  These scripts are not endorsed by the
Galaxy Project.

These scripts are not supported. The were produced as a exercise in
understanding how to configure CernVM-FS without using Ansible.  They
are provided on an "as is" basis with no guarantees.

## Requirements

The proxy setup script has been tested on:

- CentOS 7
- CentOS 8

These client setup script have been tested on:

- CentOS 7
- CentOS 8
- Ubuntu 20.04
- Ubuntu 18.04 (?)
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

The client hosts indicate which IP addresses can connect to the
proxy. It must include all the machines that will be clients,
otherwise they won't be permitted to connect to the proxy. Provide one
or more CIDR values (e.g. "192.168.1.0/24" or "10.10.0.0/16").

The script will:

- install the Squid proxy server
- configure the Squid proxy server
- start and enable the Squid proxy server

### Client

To setup a Galaxy Project CernVM-FS client, run:

```sh
sudo ./cvmfs-galaxy-client-setup.sh PROXY_ADDRESSES
```

The proxy addresses are one or more IP addresses of the proxy
servers. The values can include an optional port number following a
colon (e.g. "10.10.123.123:8080"). If omitted, it defaults to port
3128.

The script will:

- install the CernVM-FS software
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
cache

The default is 4 GiB. It is recommended the cache size is between 4
GiB and 50 GiB, but it depends on how the client will use the
repositories and the available storage on the client host.

### Dynamic configuration

By default, it is setup to use dynamic configurations from the
_cvmfs-config.galaxyproject.org_ repository. That automatically gives
access to all of the Galaxy Project repositories.

## Acknowledgements

This work is supported by the Australian BioCommons which is enabled
by NCRIS via Bioplatforms Australia funding


## See also

- [usegalaxy.org Reference data](https://galaxyproject.org/admin/reference-data-repo/)

- [Reference Data with CVMFS](https://training.galaxyproject.org/training-material/topics/admin/tutorials/cvmfs/tutorial.html) tutorial for using CVMFS with Ansible

- [Ansible scripts](https://github.com/galaxyproject/ansible-cvmfs) for CVMFS from the Galaxy Project
