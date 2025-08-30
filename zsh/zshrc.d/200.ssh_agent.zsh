# Find and use the systemd-managed ssh-agent socket
export SSH_AUTH_SOCK=$(systemctl --user show-environment | grep -oP 'SSH_AUTH_SOCK=\K.*')
