#!/usr/bin/env bash

AUR_PKGNAME=""  # TODO: Add your package name here
HEALTHCHECK_URL=""  # TODO: Add your healthchecks.io URL here

AUR_VERSION=""
LIVE_VERSION=""

get_aur_version() {
    AUR_VERSION=$(curl -fsSL "https://aur.archlinux.org/packages/$AUR_PKGNAME" \
        | grep "Package Details:" \
        | grep -oP "(?<=$AUR_PKGNAME )[0-9.]+")
}

get_live_version() {
    # TODO: Add logic to retrieve the upstream. The following template works for GitHub to retrieve the tag of the latest release, which is often used by repository owners to store the version number.

    local OWNER=""
    local REPO=""

    LIVE_VERSION=$(curl -fsSL https://api.github.com/repos/$OWNER/$REPO/releases/latest \
        | jq -r ".tag_name")
}

do_update() {
    mkdir -p "$HOME/.tmp"
    tmpdir=$(mktemp -d --tmpdir="$HOME/.tmp")
    cd "$tmpdir"

    git clone "ssh://aur@aur.archlinux.org/$AUR_PKGNAME.git"
    cd "$AUR_PKGNAME"

    sed -i "s/^pkgver=.*/pkgver=${LIVE_VERSION}/" PKGBUILD
    updpkgsums
    makepkg --printsrcinfo > .SRCINFO

    git add PKGBUILD .SRCINFO
    git commit -m "Update to version $LIVE_VERSION (automatic)"
    git push

    echo "Update complete!"
}

send_healthcheck() {
    local status="$1"
    curl -fsSL "$HEALTHCHECK_URL/$status" >/dev/null
}

main() {
    get_aur_version
    get_live_version

    if [[ -z "$AUR_VERSION" ]]; then
	echo "Failed to fetch AUR version!"
	send_healthcheck "fail"
	exit 1
    elif [[ -z "$LIVE_VERSION" ]]; then
	echo "Failed to fetch live version!"
	send_healthcheck "fail"
	exit 1
    fi

    if [[ "$AUR_VERSION" == "$LIVE_VERSION" ]]; then
        echo "No update needed."
        send_healthcheck "0"
        exit 0
    fi

    echo
    echo "New version detected!"
    echo "Upstream: $LIVE_VERSION"
    echo "AUR:      $AUR_VERSION"
    echo

    send_healthcheck "start"
    do_update
    send_healthcheck "0"
}

main
