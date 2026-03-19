### Quick and dirty (very small) VM cluster for JAX

## general configuration

# detect Operating System
if RUBY_PLATFORM =~ /linux/
  HOST_OS="linux"
else
  HOST_OS="nonlinux"
end

# get number of cluster peers from env. variable PEERS
# default: 3 nodes if not specified
NUM_OF_PEERS = ENV.fetch("PEERS", 3).to_i

# configuration for base provisioning
PROVISION_DIR="provision/sh"
DEB_DIR="provision/pkg"
UBUNTU_VER="22.04"

## cluster networking

# private network 'jax_cluster' on 192.168.56.x
# master on 192.168.56.30
# nodes on 192.168.56.31, .32, ..
NETWORK_NAME="jax_cluster"
NETWORK_IP_BASE="192.168.56"
MASTER_IP_OCTET=30

## naming

# host names (used also as Vagrant names)
MASTER_HOST_NAME="master"
NODE_HOST_NAME_BASE="node"

# VM names
VM_PREFIX="JAXplayground"
MASTER_VM_NAME="#{VM_PREFIX}_#{MASTER_HOST_NAME}"
NODE_VM_NAME_BASE="#{VM_PREFIX}_#{NODE_HOST_NAME_BASE}"

# peer details
vm_name_entries = []
hostname_entries = []
ip_entries = []
hosts_entries = []

# per node variables
(1..NUM_OF_PEERS).each do |i|
  if i == 1
    vm_name   = "#{MASTER_VM_NAME}"                       # Vagrant machine name
    hostname  = "#{MASTER_HOST_NAME}"                     # hostname inside the VM
    ip        = "#{NETWORK_IP_BASE}.#{MASTER_IP_OCTET}"   # master IP
  else
    worker_id = i - 1   # so second VM -> node1, third -> node2, etc.
    vm_name   = "#{NODE_VM_NAME_BASE}#{worker_id}"
    hostname  = "#{NODE_HOST_NAME_BASE}#{worker_id}"
    ip        = "#{NETWORK_IP_BASE}.#{MASTER_IP_OCTET + worker_id}"
  end
  vm_name_entries << vm_name
  hostname_entries << hostname
  ip_entries << "#{ip}"
  hosts_entries << "#{ip} #{hostname}"
end

HOSTS_FILE_CONTENT = hosts_entries.join("\n")
IP_FILE_CONTENT = ip_entries.join("\n")
HOSTNAME_FILE_CONTENT = hostname_entries.join("\n")

## VMs
MEM_SIZE=4096
CPUS=2

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-#{UBUNTU_VER}"

  (1..NUM_OF_PEERS).each do |i|
    config.vm.define hostname_entries[i-1] do |node|
      node.vm.hostname = hostname_entries[i-1]
      node.vm.network "private_network", ip: ip_entries[i-1], virtualbox__intnet: NETWORK_NAME

      # special provisioning for master only
      # dump hostnames and ip addresses to files
      if i == 1
        node.vm.provision "ip_list",
          type: "shell",
          inline: "echo -e \"#{IP_FILE_CONTENT}\" > /vagrant/ip.list"
          # Vagrant manipulates (badly) '/etc/hosts', a workaround is needed
          # see: https://github.com/hashicorp/vagrant/issues/7263
        node.vm.provision "hosts",
          type: "shell",
          inline: "echo -e \"#{HOSTS_FILE_CONTENT}\" > /vagrant/hosts.list"
        node.vm.provision "hostnames",
          type: "shell",
          inline: "echo -e \"#{HOSTNAME_FILE_CONTENT}\" > /vagrant/hostnames.list"
      end

      node.vm.provision "config",
        type: "shell",
        path: "./#{PROVISION_DIR}/config.sh"
      node.vm.provision "install",
        type: "shell",
        path: "./#{PROVISION_DIR}/install.sh",
        args: ["#{DEB_DIR}","#{HOST_OS}"],
        privileged: false
      node.vm.provision "add",
        type: "shell",
        path: "./#{PROVISION_DIR}/add.sh",
        args: ["#{DEB_DIR}","#{HOST_OS}"],
        privileged: false,
        run: "never"
      node.vm.provider "virtualbox" do |vb|
        vb.name = vm_name_entries[i-1]
        vb.linked_clone = true
        vb.memory = MEM_SIZE
        vb.cpus = CPUS
      end
    end
  end
end
