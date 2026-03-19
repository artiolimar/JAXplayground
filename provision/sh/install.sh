#!/bin/bash

# configure packages to install
JAX_VER="0.4.35"
PYTHON3_VER="3.10"
OPTIONAL_PKGS_OS=""
OPTIONAL_PKGS_CONDA="conda-forge::pandas conda-forge::scikit-learn"


# create and go to provision packages dir
#
PROVISION_DIR="/vagrant/$1"
if [ ! -d "$PROVISION_DIR" ]; then
	mkdir "$PROVISION_DIR"
fi
cd "$PROVISION_DIR"


# 'master', at first,  will find dir empty
#
if [ ! -z "$( ls -A $PROVISION_DIR )" ]; then
	#
	# 'node1' and 'node2' here (dir already populated by 'master')
	#
	sudo dpkg -i *.deb
else
	# 'master' here
	#
	# add packages
	echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' | sudo tee /etc/apt/apt.conf.d/99-keep-downloads
	export DEBIAN_FRONTEND=noninteractive
	sudo apt-mark hold linux-generic linux-headers-generic linux-image-generic
	sudo apt-mark hold $(uname -r)
	sudo apt-mark hold linux-firmware
	sudo apt update
	sudo apt -y upgrade
	sudo apt install -y python3 python3-setuptools python3-pip python3-virtualenv openmpi-bin openmpi-common libopenmpi-dev $OPTIONAL_PKGS_OS
	#
	# move them to a shared folder for node1 and node1
	sudo mv -v /var/cache/apt/archives/*.deb ./

	# download miniconda3
	if [ ! -f "$PROVISION_DIR/miniconda.sh" ]; then
		wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$PROVISION_DIR/miniconda.sh"
	fi
fi

# install miniconda3
sed -i '/^# source.*initialize$/d' ~/.bashrc
sed -i '/^source \~\/miniconda3\/bin\/activate jax$/d' ~/.bashrc
mkdir -p ~/miniconda3
mkdir -p "$PROVISION_DIR/conda"
bash "$PROVISION_DIR/miniconda.sh" -b -u -p ~/miniconda3
source ~/miniconda3/etc/profile.d/conda.sh
conda init --all

conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

HOST_OS="$2"
if [ "$HOST_OS" = "linux" ]; then
	echo -e "pkgs_dirs:\n    - $PROVISION_DIR/conda" >> ~/.condarc
fi

# install JAX
cd ~
conda create -n jax python="$PYTHON3_VER"
source ~/miniconda3/bin/activate jax
echo -e "\nsource ~/miniconda3/bin/activate jax" >> ~/.bashrc

conda install -q conda-forge::jax="$JAX_VER" flax openmpi mpi4py $OPTIONAL_PKGS_CONDA

echo -e "\nexport OMPI_MCA_orte_launch_agent=/home/vagrant/miniconda3/envs/jax/bin/orted" >> ~/.bashrc
