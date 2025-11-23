SHELL = /bin/zsh

PLATFORM := $(shell uname -s)

ifeq ("${PLATFORM}", "Darwin")
CLOUD_DIR = /Volumes/Cloud
KITTY_OS = macos
VSCODE_CONFIG_DIR := ${HOME}/Library/Application Support/Code/User

config: \
	config-common \
	configure-desktop-macos

else ifeq ("${PLATFORM}", "Linux")
CLOUD_DIR := ${HOME}/Cloud
KITTY_OS = linux
VSCODE_CONFIG_DIR := ${HOME}/.config/Code/User

config: \
	config-common \
	configure-apt \
	configure-desktop-gnome \
	configure-flatpak \
	configure-libvirt \
	configure-pam-limits \
	configure-sysctl \
	configure-timedatectl \
	configure-vagrant \
	configure-zsh

endif

config-common: \
	configure-abcde \
	configure-bash-scripts \
	configure-ack \
	configure-git \
	configure-gnupg \
	configure-kitty \
	configure-sqlite3 \
	configure-ssh \
	configure-tmux \
	configure-vim \
	configure-vscode


# Configuration targets
configure-abcde:
	# Configure abcde
	ln -f -s ${PWD}/abcde/abcde.conf ${HOME}/.abcde.conf
	# Link CDDB cache directory
	if [[ ! -h ${HOME}/.cddb ]]; then ln -f -s ${CLOUD_DIR}/Music/CDDB ${HOME}/.cddb; fi

configure-ack:
	# Configure Ack
	ln -f -s ${PWD}/ack/ackrc ${HOME}/.ackrc

configure-apt:
	# Configure APT
	sudo ln -f -s ${PWD}/apt/local /etc/apt/apt.conf.d/99local

configure-bash-scripts:
	# Install bash scripts
	sudo mkdir -p /usr/local/bin/
	sudo ln -f -s ${PWD}/bash/scripts/resample.bash /usr/local/bin/resample

configure-desktop-gnome:
	# Disable updates in GNOME Software
	gsettings set org.gnome.software allow-updates false
	gsettings set org.gnome.software download-updates false
	gsettings set org.gnome.software download-updates-notify false

configure-desktop-macos:
	# Set delay for hot corners
	defaults write com.apple.dock wvous-corner-action-delay -float 0.2

configure-flatpak:
	# Add Flathub repo for Flatpak
	flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

configure-git:
	# Configure Git
	ln -f -s ${PWD}/git/gitconfig ${HOME}/.gitconfig
	ln -f -s ${PWD}/git/gitignore ${HOME}/.gitignore

configure-gnupg:
	# Install pinentry-auto script
	sudo mkdir -p /usr/local/bin/
	sudo ln -f -s ${PWD}/gnupg/pinentry-auto.sh /usr/local/bin/pinentry-auto
	# Configure GnuPG agent
	mkdir -p ${HOME}/.gnupg/
	ln -f -s ${PWD}/gnupg/gpg-agent.conf ${HOME}/.gnupg/gpg-agent.conf

configure-ideavim:
	# Configure IdeaVim
	ln -f -s ${PWD}/ideavim/ideavimrc ${HOME}/.ideavimrc

configure-kitty:
	# Configure kitty terminal
	mkdir -p ${HOME}/.config/kitty/
	ln -f -s ${PWD}/kitty/kitty.conf ${HOME}/.config/kitty/kitty.conf
	ln -f -s ${PWD}/kitty/kitty-${KITTY_OS}.conf ${HOME}/.config/kitty/kitty-${KITTY_OS}.conf

configure-libvirt:
	# Add current user to `libvirt` group
	getent group libvirt || sudo groupadd libvirt
	sudo usermod --append --groups libvirt ${USER}

configure-pam-limits:
	# Set resource limits for `audio` group
	sudo cp ${PWD}/pam_limits/audio.conf /etc/security/limits.d/95-audio.conf
	# Add current user to `audio` group
	getent group audio || sudo groupadd audio
	sudo usermod --append --groups audio ${USER}

configure-sqlite3:
	# Configure SQLite3
	ln -f -s ${PWD}/sqlite3/sqliterc ${HOME}/.sqliterc

SSH_INCLUDE_LINE := "Include ${PWD}/ssh/config"
configure-ssh:
	# Configure SSH
	mkdir -p ${HOME}/.ssh/
	if [[ ! -f ${HOME}/.ssh/config ]]; then touch ${HOME}/.ssh/config; fi
	grep --line-regexp --fixed-strings --quiet -- ${SSH_INCLUDE_LINE} ${HOME}/.ssh/config || printf '\n%s\n' ${SSH_INCLUDE_LINE} >> ${HOME}/.ssh/config

configure-sysctl:
	# Configure sysctl settings
	sudo cp ${PWD}/sysctl/local.conf /etc/sysctl.d/local.conf

configure-timedatectl:
	# Configure system time to be UTC
	sudo timedatectl set-local-rtc 0

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

configure-vscode:
	# Configure VS Code
	mkdir -p "${VSCODE_CONFIG_DIR}"
	ln -f -s ${PWD}/vscode/settings.json "${VSCODE_CONFIG_DIR}/settings.json"
	# Disable key press and hold for VSCode under MacOS
	if [[ "${PLATFORM}" = "Darwin" ]]; then defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false; fi

configure-zsh:
	# Configure zsh
	ln -f -s ${PWD}/zsh/zprofile ${HOME}/.zprofile
	ln -f -s ${PWD}/zsh/zshrc ${HOME}/.zshrc


# Installation targets
install-apt-packages:
	xargs --arg-file=<(grep --invert-match "^#" install/apt-packages.txt) --no-run-if-empty -- sudo apt-get install --no-install-recommends --yes

install-brew-packages:
	brew bundle install --file=install/Brewfile
