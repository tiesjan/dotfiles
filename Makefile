config: \
	configure-ack \
	configure-git \
	configure-gnome-desktop \
	configure-gpg \
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
	# Configure Ack globally
	ln -f -s ${PWD}/ack/ackrc ${HOME}/.ackrc
	# Configure Ack for Smart.pr
	mkdir -p ${HOME}/Documents/Smart.pr/
	ln -f -s ${PWD}/ack/ackrc-smartpr ${HOME}/Documents/Smart.pr/.ackrc

configure-git:
	# Configure Git
	ln -f -s ${PWD}/git/gitconfig ${HOME}/.gitconfig
	ln -f -s ${PWD}/git/gitconfig-personal ${HOME}/.gitconfig-personal
	ln -f -s ${PWD}/git/gitconfig-smartpr ${HOME}/.gitconfig-smartpr
	ln -f -s ${PWD}/git/gitignore ${HOME}/.gitignore

configure-gnome-desktop:
	# Desktop appearance
	gsettings set org.gnome.desktop.calendar show-weekdate true
	gsettings set org.gnome.desktop.interface clock-show-weekday false
	gsettings set org.gnome.desktop.interface show-battery-percentage true
	gsettings set org.gnome.desktop.input-sources xkb-options "['compose:ralt']"
	
	# Disable updates in GNOME Software
	gsettings set org.gnome.software allow-updates false
	gsettings set org.gnome.software download-updates false
	gsettings set org.gnome.software download-updates-notify false
	
	# Ignore directories in GNOME Tracker
	mkdir -p ${HOME}/Documents/Smart.pr/
	if [ ! -f ${HOME}/Documents/Smart.pr/.trackerignore ]; then touch ${HOME}/Documents/Smart.pr/.trackerignore; fi
	mkdir -p ${HOME}/Documents/VirtualBox/
	if [ ! -f ${HOME}/Documents/VirtualBox/.trackerignore ]; then touch ${HOME}/Documents/VirtualBox/.trackerignore; fi

configure-gpg:
	# Configure GPG agent
	mkdir -p ${HOME}/.gnupg/
	ln -f -s ${PWD}/gnupg/gpg-agent.conf ${HOME}/.gnupg/gpg-agent.conf

configure-pip:
	# Configure pip
	mkdir -p ${HOME}/.config/pip/
	ln -f -s ${PWD}/pip/pip.conf ${HOME}/.config/pip/pip.conf

configure-npm:
	# Configure NPM
	ln -f -s ${PWD}/npm/npmrc ${HOME}/.npmrc

configure-ssh:
	# Configure SSH
	mkdir -p ${HOME}/.ssh/
	ln -f -s ${PWD}/ssh/config ${HOME}/.ssh/config

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
