SHELL := /bin/bash

config: \
	configure-abcde \
	configure-ack \
	configure-ghci \
	configure-git \
	configure-gnome-desktop \
	configure-gpg \
	configure-ideavim \
	configure-libvirt \
	configure-npm \
	configure-pip \
	configure-ssh \
	configure-tmux \
	configure-vagrant \
	configure-vim \
	source-bashrc \
	source-profile

install: \
	install-apt-packages \
	install-pipx-packages


# Configuration targets
configure-abcde:
	# Configure abcde
	ln -f -s ${PWD}/abcde/abcde.conf ${HOME}/.abcde.conf

configure-ack:
	# Configure Ack
	ln -f -s ${PWD}/ack/ackrc ${HOME}/.ackrc

configure-ghci:
	# Configure GHCi
	ln -f -s ${PWD}/ghci/ghci ${HOME}/.ghci
	chmod 0600 ${HOME}/.ghci

configure-git:
	# Configure Git
	ln -f -s ${PWD}/git/gitconfig ${HOME}/.gitconfig
	ln -f -s ${PWD}/git/gitignore ${HOME}/.gitignore

configure-gnome-desktop:
	# Disable updates in GNOME Software
	gsettings set org.gnome.software allow-updates false
	gsettings set org.gnome.software download-updates false
	gsettings set org.gnome.software download-updates-notify false
	
	# Ignore home directory in GNOME Tracker
	if [ ! -f ${HOME}/.trackerignore ]; then touch ${HOME}/.trackerignore; fi

configure-gpg:
	# Configure GPG agent
	mkdir -p ${HOME}/.gnupg/
	ln -f -s ${PWD}/gnupg/gpg-agent.conf ${HOME}/.gnupg/gpg-agent.conf

configure-ideavim:
	# Configure IdeaVim
	ln -f -s ${PWD}/ideavim/ideavimrc ${HOME}/.ideavimrc

configure-libvirt:
	# Add current user to `libvirt` group
	getent group libvirt || sudo groupadd libvirt
	sudo usermod --append --groups libvirt ${USER}

configure-pip:
	# Configure pip
	mkdir -p ${HOME}/.config/pip/
	ln -f -s ${PWD}/pip/pip.conf ${HOME}/.config/pip/pip.conf

configure-npm:
	# Configure NPM
	ln -f -s ${PWD}/npm/npmrc ${HOME}/.npmrc

SSH_INCLUDE_LINE="Include ${PWD}/ssh/config"
configure-ssh:
	# Configure SSH
	mkdir -p ${HOME}/.ssh/
	if [ ! -f ${HOME}/.ssh/config ]; then touch ${HOME}/.ssh/config; fi
	grep --quiet -- ${SSH_INCLUDE_LINE} ${HOME}/.ssh/config || echo "\n${SSH_INCLUDE_LINE}" >> ${HOME}/.ssh/config

configure-tmux:
	# Configure tmux
	ln -f -s ${PWD}/tmux/tmux.conf ${HOME}/.tmux.conf

configure-vagrant:
	# Configure sudoers for Vagrant
	getent group vagrant || sudo groupadd vagrant
	sudo usermod --append --groups vagrant ${USER}
	sudo cp ${PWD}/vagrant/sudoers /etc/sudoers.d/vagrant
	sudo chown root:root /etc/sudoers.d/vagrant

configure-vim:
	# Configure Vim
	ln -f -s ${PWD}/vim/vimrc ${HOME}/.vimrc

BASHRC_SOURCE_LINE=". ${PWD}/bash/bashrc"
source-bashrc:
	# Source user definitions in .bashrc
	if [ ! -f ${HOME}/.bashrc ]; then touch ${HOME}/.bashrc; fi
	grep --quiet -- ${BASHRC_SOURCE_LINE} ${HOME}/.bashrc || echo "\n${BASHRC_SOURCE_LINE}" >> ${HOME}/.bashrc

PROFILE_SOURCE_LINE=". ${PWD}/bash/profile"
source-profile:
	# Source user definitions in .profile
	if [ ! -f ${HOME}/.profile ]; then touch ${HOME}/.profile; fi
	grep --quiet -- ${PROFILE_SOURCE_LINE} ${HOME}/.profile || echo "\n${PROFILE_SOURCE_LINE}" >> ${HOME}/.profile


# Installation targets
install-apt-packages:
	xargs --arg-file=<(grep --invert-match "^#" install/apt-packages.txt) --no-run-if-empty -- sudo apt-get install --no-install-recommends --yes

install-pipx-packages:
	xargs --arg-file=install/pipx-commands.txt --max-lines=1 --no-run-if-empty -- pipx
