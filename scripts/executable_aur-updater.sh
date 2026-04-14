#!/usr/bin/env bash

WORKDIR="/tmp/aur-updater"
AUR_SSH_BASE="ssh://aur@aur.archlinux.org"

# ################### #
# Universal functions #
# ################### #

menu() {
    echo "Select a package to update:"
    echo "1) kittenspaceagency-bin"
    echo "q) Quit"
    echo -n "> "

    read -r choice
    case "$choice" in
        1) run_update "kittenspaceagency-bin" ;;
        q|Q) exit 0 ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
}

clone_repo() {
    local pkg="$1"

    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"

    echo "Cloning AUR repo for $pkg..."
    GIT_SSH_COMMAND="ssh -o LogLevel=ERROR" \
        git clone --quiet "${AUR_SSH_BASE}/${pkg}.git" "$WORKDIR/$pkg"
}


run_update() {
    local pkg="$1"

    clone_repo "$pkg"

    case "$pkg" in
        kittenspaceagency-bin)
            update_kittenspaceagency "$pkg"
            ;;
        *)
            echo "No update function defined for $pkg"
            exit 1
            ;;
    esac
}

finalize_and_push() {
    local pkg="$1"
    local dir="$WORKDIR/$pkg"

    cd "$dir"

    echo "===GIT DIFF==="

    # Only show PKGBUILD diff, with git's own colors
    git diff --cached . ':(exclude).SRCINFO'

    echo "=============="
    echo

    echo -n "Push these changes? [y/N]: "
    read -r confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi

    git commit -m "Updated version."
    git push

    echo "Update pushed successfully."
}


# ########################## #
# Package specific functions #
# ########################## #
# User the `update_{package-name} format to keep things organized!

update_kittenspaceagency() {
    GREEN="\e[32m"
    RED="\e[31m"
    RESET="\e[0m"

    local pkg="$1"
    local dir="$WORKDIR/$pkg"

    echo
    echo "Updating $pkg..."

    # Fetch upstream version
    upstream=$(curl -fsSL https://ksa-linux.ahwoo.com/ \
        | grep -oP 'setup_ksa_v\K[0-9.]+(?=\.tar\.gz)' \
        | sort -V | tail -n1)

    # Fetch AUR version from PKGBUILD
    aur=$(grep '^pkgver=' "$dir/PKGBUILD" | cut -d= -f2)

    echo -e "    Upstream version: ${GREEN}${upstream}${RESET}"
    echo -e "    AUR version:      ${RED}${aur}${RESET}"
    echo

    if [[ "$upstream" == "$aur" ]]; then
        echo "No update needed."
        exit 0
    fi

    sed -i "s/^pkgver=.*/pkgver=${upstream}/" "$dir/PKGBUILD"
    (cd "$dir" && makepkg --printsrcinfo > .SRCINFO)

    updpkgsums

    git -C "$dir" add PKGBUILD .SRCINFO

    finalize_and_push "$pkg"
}

# #### #
# Main #
# #### #
menu
