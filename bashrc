# Disable software flow control
stty -ixon

# Set default visual editor
export VISUAL="vim"

# Prefix bash prompt if $VIM is set
if [ -v VIM ]; then
    PS1="[vim] $PS1"
fi

# Enable bash completion for aws
complete -C '`which aws_completer`' aws

# Configure ansible
export ANSIBLE_CALLBACK_WHITELIST="profile_tasks"
export ANSIBLE_RETRY_FILES_ENABLED="False"
export ANSIBLE_VAULT_IDENTITY_LIST="@${HOME}/.vault-personal,@${HOME}/.vault-smartpr"

# Configure GPG
export GPG_TTY="$(tty)"

# Configure jq
export JQ_COLORS="0;33:0;33:0;33:0;39:0;32:0;39:0;39"

# Configure pass
export PASSWORD_STORE_DIR="${HOME}/Documents/Personal/secrets"
