#!/usr/bin/env bash
# Run this with:
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColonialDagger/dotfiles/refs/heads/master/scripts/executable_lxc_setup.sh)"

BASHRC_URL="https://raw.githubusercontent.com/ColonialDagger/dotfiles/refs/heads/master/executable_dot_bashrc"

# --- CONFIG FLAGS (no prompts) ---
UPGRADE_PACKAGES=true
INSTALL_EXTRA_PACKAGES=true
SETUP_SSH_HARDENING=true
RESET_ROOT_PASSWORD=true
INSTALL_ROOT_BASHRC=true
SETUP_BITWISE_USER=true
INSTALL_FASTFETCH=true

extra_packages=(
    btop htop sudo nvtop fzf ncdu curl vim magic-wormhole cron nala tealdeer net-tools
)

# --- SINGLE PASSWORD FOR ROOT + BITWISE (with confirmation loop) ---
if $RESET_ROOT_PASSWORD; then
    while true; do
        echo "Enter a password to use for BOTH root and bitwise:"
        read -s PASSWORD1
        echo
        echo "Confirm the password:"
        read -s PASSWORD2
        echo

        if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
            PASSWORD="$PASSWORD1"
            break
        else
            echo "Passwords do not match. Please try again."
            echo
        fi
    done

    echo "root:$PASSWORD" | chpasswd
fi

# --- PACKAGE MANAGEMENT ---
if $UPGRADE_PACKAGES; then
    apt update
    apt upgrade -y
fi

# --- FASTFETCH CONDITIONAL ADD ---
if $INSTALL_FASTFETCH; then
    UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "")
    DISTRO=$(lsb_release -is 2>/dev/null || echo "")

    if [[ "$DISTRO" == "Ubuntu" ]]; then
        # Ubuntu 25.04+ → fastfetch available normally
        if dpkg --compare-versions "$UBUNTU_VERSION" ge "25.04"; then
            extra_packages+=("fastfetch")

        # Ubuntu 22.04 → 24.10 → use PPA
        elif dpkg --compare-versions "$UBUNTU_VERSION" ge "22.04"; then
            apt install -y software-properties-common
            add-apt-repository -y ppa:zhangsongcui3371/fastfetch
            apt update
            extra_packages+=("fastfetch")
        fi

    elif [[ "$DISTRO" == "Debian" ]]; then
        DEBIAN_VERSION=$(lsb_release -rs 2>/dev/null || echo "")
        if dpkg --compare-versions "$DEBIAN_VERSION" ge "13"; then
            extra_packages+=("fastfetch")
        fi
    fi
fi

# --- INSTALL ALL EXTRA PACKAGES IN ONE GO ---
if $INSTALL_EXTRA_PACKAGES; then
    apt install -y "${extra_packages[@]}"
fi

# --- SSH HARDENING ---
if $SETUP_SSH_HARDENING; then
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

    systemctl enable ssh
    systemctl restart ssh
fi

# --- ROOT .bashrc ---
if $INSTALL_ROOT_BASHRC; then
    curl -fsSL "$BASHRC_URL" > /root/.bashrc
    (crontab -l 2>/dev/null; echo "*/15 * * * * curl -fsSL $BASHRC_URL > /root/.bashrc") | crontab -
fi

# --- BITWISE USER SETUP ---
if $SETUP_BITWISE_USER; then
    if ! id bitwise &>/dev/null; then
        adduser --gecos "" --disabled-password bitwise
        usermod -aG sudo bitwise

        # Set bitwise password to same as root
        if $RESET_ROOT_PASSWORD; then
            echo "bitwise:$PASSWORD" | chpasswd
        fi
    fi

    su - bitwise -c "mkdir -p ~/.ssh"
    su - bitwise -c "chmod 700 ~/.ssh"

    su - bitwise -c "curl -fsSL https://github.com/ColonialDagger.keys > ~/.ssh/authorized_keys"
    su - bitwise -c "chmod 600 ~/.ssh/authorized_keys"

    su - bitwise -c "(crontab -l 2>/dev/null; echo '*/15 * * * * curl -fsSL https://github.com/ColonialDagger.keys > ~/.ssh/authorized_keys') | crontab -"
    su - bitwise -c "(crontab -l 2>/dev/null; echo '*/15 * * * * curl -fsSL $BASHRC_URL > ~/.bashrc') | crontab -"

    su - bitwise -c "curl -fsSL $BASHRC_URL > ~/.bashrc"
fi

echo ""
echo "=============================================================="
echo " Intel Arc A310 Reminder"
echo "=============================================================="
echo "For GPU support to work, make sure:"
echo " -> This LXC container is PRIVILEGED"
echo " -> The following lines are present in /etc/pve/lxc/<ID>.conf:"
echo ""
echo "      lxc.cgroup2.devices.allow: c 226:129 rwm"
echo "      lxc.mount.entry: /dev/dri/renderD129 dev/dri/renderD129 none bind,optional,create=file"
echo ""
echo "Without these, QSV/VAAPI/OpenCL will NOT work inside the container."
echo "=============================================================="
echo ""

echo "All changes completed! Restarting now..."
reboot 0
