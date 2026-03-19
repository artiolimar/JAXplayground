#!/bin/bash

# configure packages to post-install
OPTIONAL_PKGS_OS=""
OPTIONAL_PKGS_CONDA=""


# create and go to provision packages dir
#
PROVISION_DIR="/vagrant/$1"
if [ ! -d "$PROVISION_DIR" ]; then
	mkdir "$PROVISION_DIR"
fi
cd "$PROVISION_DIR"

if [ "$OPTIONAL_PKGS_OS" = "" ]; then
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
		sudo apt update
		sudo apt install -y "$OPTIONAL_PKGS_OS"
		#
		# move them to a shared folder for node1 and node1
		sudo mv -v /var/cache/apt/archives/*.deb ./
	fi
fi

if [ "$OPTIONAL_PKGS_OS" = "" ]; then
	# install conda packages
	source ~/miniconda3/bin/activate jax
	conda install -q "$OPTIONAL_PKGS_CONDA"
fi
