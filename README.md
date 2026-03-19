# JAXplayground

Quick and dirty VM cluster for JAX.

## What you get

You'll end up with a small cluster of three VMs (three by default), one *chief* (**master**) and some other *workers* (two by default, **node1** and **node2**), configured for testing and development of distributed computation with JAX.

The repo directory contains a bunch of files:

- a `Vagrantfile` and provisioning scripts (`provision/sh/*.sh`) to pull up the cluster

- some shell scripts to submit jobs to the cluster or the single node
  
  - `rrun` to run an arbitrary command on a remote node
  
  - `crun` to run an arbitrary command on the whole cluster
  
  - `djaxrun` to run a (distributed) JAX python script (on the whole cluster)
  
  - `djaxstop` to stop it

## Setup

### prerequisites

1. install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

2. install [Vagrant](https://developer.hashicorp.com/vagrant/downloads)

### building

1. clone the repo with  `git clone http://catafalcon.bologna.enea.it/gogs/marcello.artioli/JAXplayground`

2. go to it with `cd JAXplayground`

3. check the build configuration in `Vagrantfile` is OK, mainly
   
   - UBUNTU_VER variable: the base box is currently "bento/ubuntu-22.04"

4. check the package installation in `/provision/sh/install.sh` is OK
   
   - JAX_VER="0.4.35": JAX version (in the virtual env)
   
   - PYTHON3_VER="3.10": Python version (in the virtual env)
   
   - OPTIONAL_PKGS_OS="": space separated list of additional packages (in the operating system)
   
   - OPTIONAL_PKGS_CONDA="": space separated list of additional packages (in the virtual env)

5. build the cluster with `vagrant up`

6. check the installation is OK with `vagrant ssh master` and then with `python3 /vagrant/sample_test.py` (then `exit`)

7. check the distributed configuration is OK with `./djaxrun sample_test_distributed.py`

### adding packages

The VMs are stripped down almost to the bare minimum to run JAX.

If you need more packages:

1. edit the provision script `install.sh`

2. destroy the cluster with `vagrant destroy`

3. recreate the cluster

or:

1. edit the provision script `add.sh`

2. re-provision the cluster with `vagrant provision --provision-with add`

## How to use

The repo directory is the `/vagrant` folder mounted inside each VM and is the working directory.

Every command must be issued from there (there are no commands in *path*).

### commands

- `rrun <node name> <command>`: this script uses `vagrant ssh -c` to remotely execute a command; nothing is echoed to screen but output is redirected to `<node name>.out` and (error) messages logged to `<node name>.err`

- `crun <command>`: this script uses `rrun` to send the same command to all three nodes of the cluster, and
  
  - if the optional `-q|--quiet` is given, then the result of the *chief* node is NOT echoed on *stdout*
  
  - output is redirected to `<node name>.out`
  
  - (error) messages are redirected to `<node name>.err`

- `djaxrun <python script>`: this script uses `crun` to dispatch the job to all peers of the cluster (via `mpirun` issued from the *master*)
  
  - prompts for a grace period of three seconds before sending
  
  - has the same input/output behaviour of `crun`

- `djaxstop` halts and kills every python script on the cluster (JAX client/server processes are not killable with a simple `kill`)

### running

1. go to the working directory
   `cd JAXplayground`

2. put here your main JAX python script `mainscript.py`

3. run it 
   `./djaxrun mainscript.py`

### more than three peers

If you want a different number of peers in cluster, put a preceeding `PEERS=<n>` before every command invocation, e.g.:

`PEERS=4 vagrant up` will build a cluster with **master**, **node1**, **node2** and **node3**;

`PEERS=4 ./djaxrun mainscript.py` will run the script also on the fourth node.
