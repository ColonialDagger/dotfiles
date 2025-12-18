#!/bin/bash
# Run this to run this script quickly as root: curl -fsSL https://termbin.com/e3ld | bash

# Install packages
apt install -y btop htop iotop nvtop iftop sudo fzf ncdu curl vim magic-wormhole

# Create bitwise user
adduser --gecos "" bitwise
usermod -aG sudo bitwise

su - bitwise -c "mkdir /home/bitwise/.ssh"
su - bitwise -c "chmod 700 /home/bitwise/.ssh"
su - bitwise -c "touch /home/bitwise/.ssh/authorized_keys"
su - bitwise -c "chmod 600 /home/bitwise/.ssh/authorized_keys"

su - bitwise -c "curl https://github.com/ColonialDagger.keys > /home/bitwise/.ssh/authorized_keys"
su - bitwise -c "(crontab -l ; echo '*/15 * * * * curl https://github.com/ColonialDagger.keys > /home/bitwise/.ssh/authorized_keys') | crontab -"

BASHRC_URL="https://termbin.com/kcdg"
su - bitwise -c "curl $BASHRC_URL > /home/bitwise/.bashrc"
su - root -c "curl $BASHRC_URL > /root/.bashrc"

# Set up SSH connections via keys only
sed -i '/#PermitRootLogin prohibit-password/c\PermitRootLogin no' /etc/ssh/sshd_config
sed -i '/#PubkeyAuthentication yes/c\PubkeyAuthentication yes' /etc/ssh/sshd_config
sed -i '/#PasswordAuthentication yes/c\PasswordAuthentication no' /etc/ssh/sshd_config
sed -i '/#PermitEmptyPasswords no/c\PermitEmptyPasswords no' /etc/ssh/sshd_config
systemctl enable sshd

# Reboot to initialize everything
reboot 0
