#!/bin/bash
# This setup is meant for customized setup of an LXC container for daytona.kabr.org.
# Run this script with:
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColonialDagger/dotfiles/refs/heads/master/scripts/executable_lxc_setup.sh)"

BASHRC_URL="https://raw.githubusercontent.com/ColonialDagger/dotfiles/refs/heads/master/executable_dot_bashrc"

prompt() {
    local question="$1"
    local result_var="$2"

    read -p "$question [y/n]: " response
    case "$response" in
        [Yy]* ) eval "$result_var=true";;
        * ) eval "$result_var=false";;
    esac
}

# Define your package list
extra_packages=(
    btop htop sudo fzf ncdu curl vim magic-wormhole cron nala tldr-hs
)

# PROMPTS

# Package management
prompt "Do you want to upgrade all packages?" ANS_UPGRADE ###
prompt "Do you want to add a suite of extra, useful packages?" ANS_EXTRA_PACKAGES ###

# SSH and user management
prompt "Do you want to set up key-based authentication?" ANS_SSH ###
prompt "Do you want to reset the root password?" ANS_ROOT_PASS ###
if $ANS_ROOT_PASS; then
    passwd root
fi
prompt "Do you want to install .bashrc for the root user?" ANS_ROOT_BASHRC
prompt "Do you want to set up a bitwise user?" ANS_BITWISE
if $ANS_BITWISE; then  # Create user now to set the password.
    adduser --gecos "" bitwise
    usermod -aG sudo bitwise
fi

# CIFS mount
prompt "Do you want to mount a SMB share?" ANS_SMB_MOUNT
if $ANS_SMB_MOUNT; then
    extra_packages+=("cifs-utils")
    extra_packages+=("autofs")

    # Prompt for domain
    while true; do
        read -p "Enter the Samba domain (e.g., nas.daytona.kabr.org): " domain

        echo "Pinging $domain..."
        if ping -c 1 -W 1 "$domain" &>/dev/null; then
            break
        else
            echo "Could not reach $domain. Try again or press Ctrl+C to cancel."
        fi
    done

    # Prompt for shares
    while true; do
        echo "Enter the names of the shares you want to mount (one per line). Press Ctrl+D when done:"
        mapfile -t shares

        if [[ ${#shares[@]} -ne 0 ]]; then
            break
        else
            echo "No shares entered"0jlc
        fi
    done

    # Prompt for username and password
    read -p "Enter your Samba username: " smb_user

    while true; do
        read -s -p "Enter your Samba password: " smb_pass1
        echo
        read -s -p "Confirm your Samba password: " smb_pass2
        echo

        if [[ "$smb_pass1" == "$smb_pass2" ]]; then
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
fi

# Nvidia drivers
prompt "Do you want to install Nvidia drivers?" ANS_NVIDIA
if $ANS_NVIDIA; then
    extra_packages+=("nvtop")
fi

# RUNTIME

# Add local apt-cacher-ng proxy
# The local DNS server (PiHole) must point directly to the IP
prompt "Do you want to use the local APT package proxy (apt.daytona.kabr.org)?" ANS_APT_PROXY
if $ANS_APT_PROXY; then
    echo 'Acquire::http::Proxy "http://apt.daytona.kabr.org:3142/";' | sudo tee /etc/apt/apt.conf.d/02proxy
fi

# Package management
if $ANS_UPGRADE; then
    apt update
    apt upgrade -y
fi

if $ANS_EXTRA_PACKAGES; then
    apt install -y "${extra_packages[@]}"
fi

# SSH and user management
if $ANS_SSH; then
    # Set up SSH connections via keys only
    sed -i '/#PermitRootLogin prohibit-password/c\PermitRootLogin no' /etc/ssh/sshd_config
    sed -i '/#PubkeyAuthentication yes/c\PubkeyAuthentication yes' /etc/ssh/sshd_config
    sed -i '/#PasswordAuthentication yes/c\PasswordAuthentication no' /etc/ssh/sshd_config
    sed -i '/#PermitEmptyPasswords no/c\PermitEmptyPasswords no' /etc/ssh/sshd_config
    systemctl enable sshd
    systemctl restart sshd
fi

if $ANS_ROOT_BASHRC; then
    su - root -c "curl $BASHRC_URL > /root/.bashrc"
    su - root -c "(crontab -l ; echo '*/15 * * * * curl -fsSL $BASHRC_URL > /root/.bashrc') | crontab -"
fi

if $ANS_BITWISE; then
    su - bitwise -c "mkdir /home/bitwise/.ssh"
    su - bitwise -c "chmod 700 /home/bitwise/.ssh"
    su - bitwise -c "touch /home/bitwise/.ssh/authorized_keys"
    su - bitwise -c "chmod 600 /home/bitwise/.ssh/authorized_keys"
    su - bitwise -c "curl -fsSL https://github.com/ColonialDagger.keys > /home/bitwise/.ssh/authorized_keys"

    su - bitwise -c "(crontab -l ; echo '*/15 * * * * curl -fsSL https://github.com/ColonialDagger.keys > /home/bitwise/.ssh/authorized_keys') | crontab -"
    su - bitwise -c "(crontab -l ; echo '*/15 * * * * curl -fsSL $BASHRC_URL > /home/bitwise/.bashrc') | crontab -"

    su - bitwise -c "curl -fsSL $BASHRC_URL > /home/bitwise/.bashrc"
fi

# CIFS mount
if $ANS_SMB_MOUNT; then
    addgroup nas

    touch /root/.smbcredentials
    echo "username=$smb_user" >> /root/.smbcredentials
    echo "password=$smb_pass1" >> /root/.smbcredentials
    mkdir /media/$domain

    echo >> /etc/auto.master
    echo "/media/$domain /etc/auto.cifs --ghost --timeout=60" >> /etc/auto.master

    touch /etc/auto.cifs
    for share in "${shares[@]}"; do
        echo "$share -fstype=cifs,credentials=/root/.smbcredentials,rw,uid=1000,gid=nas,file_mode=0775,dir_mode=0775 ://$domain/$share" >> /etc/auto.cifs
    done

    systemctl restart autofs
fi

if $ANS_NVIDIA; then
    echo ""
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.105.08/NVIDIA-Linux-x86_64-580.105.08.run -O /tmp/NVIDIA-Linux-x86_64-580.105.08.run
    chmod +x /tmp/NVIDIA-Linux-x86_64-580.105.08.run
    /tmp/NVIDIA-Linux-x86_64-580.105.08.run --no-kernel-module -no-questions --silent
    echo "Add the following data to /etc/pve/lxc/<id>.conf on the Proxmox host:"
    echo ""
    echo "# Allow cgroup access"
    echo "lxc.cgroup2.devices.allow = c 195:0 rw"
    echo "lxc.cgroup2.devices.allow = c 195:255 rw"
    echo "lxc.cgroup2.devices.allow = c 195:254 rw"
    echo "lxc.cgroup2.devices.allow = c 510:0 rw"
    echo "lxc.cgroup2.devices.allow = c 510:1 rw"
    echo "lxc.cgroup2.devices.allow = c 10:144 rw"
    echo ""
    echo "# Pass through device files"
    echo "lxc.mount.entry = /dev/nvidia0 dev/nvidia0 none bind,optional,create=file"
    echo "lxc.mount.entry = /dev/nvidiactl dev/nvidiactl none bind,optional,create=file"
    echo "lxc.mount.entry = /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file"
    echo "lxc.mount.entry = /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file"
    echo "lxc.mount.entry = /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file"
    echo "lxc.mount.entry = /dev/nvram dev/nvram none bind,optional,create=file"
    echo ""
fi

echo "All changes complated! Restarting now..."
reboot 0
