config: \
	configure-ack \
	configure-docker \
	configure-git \
	configure-gnome-desktop \
	configure-gpg \
	configure-ideavim \
	configure-npm \
	configure-pip \
	configure-ssh \
	configure-vagrant \
	configure-vim \
	source-bashrc \
	source-profile

install: \
	install-pip-packages


# Configuration targets
configure-ack:
	# Configure Ack
	ln -f -s ${PWD}/ack/ackrc ${HOME}/.ackrc

configure-docker:
	# Add current user to `docker` group
	getent group docker || sudo groupadd docker
	sudo usermod --append --groups docker ${USER}
	# Configure UID/GID remapping namespace for current user
	echo "{\"userns-remap\": \"${USER}\"}" | sudo tee /etc/docker/daemon.json

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
install-pip-packages:
	python3 -m pip install --requirement install/pip-packages.txt

upgrade-pip-packages:
	python3 -m pip install --upgrade --requirement install/pip-packages.txt
