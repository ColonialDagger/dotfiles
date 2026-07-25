#!/usr/bin/env bash

AUR_PKGNAME="steamfetch"
HEALTHCHECK_URL="https://hc-ping.com/b2ab4196-8e30-44c7-99a8-c742ca840a32"

AUR_VERSION=""
LIVE_VERSION=""

get_aur_version() {
    AUR_VERSION=$(curl -fsSL "https://aur.archlinux.org/packages/$AUR_PKGNAME" \
        | grep "Package Details:" \
        | grep -oP "(?<=$AUR_PKGNAME )[0-9.]+")
}

get_live_version() {
    LIVE_VERSION=$(curl -fsSL https://api.github.com/repos/unhappychoice/steamfetch/releases/latest \
        | jq -r ".tag_name" \
        | cut --characters 2-)
}

do_update() {
    tmpdir=$(mktemp -d --tmpdir=~/.tmp)
    cd "$tmpdir"

    git clone "ssh://aur@aur.archlinux.org/$AUR_PKGNAME.git"
    cd "$AUR_PKGNAME"

    # UPDATE METHOD GOES BELOW HERE

    sed -i "s/^pkgver=.*/pkgver=${LIVE_VERSION}/" PKGBUILD
    updpkgsums
    makepkg --printsrcinfo > .SRCINFO

    git add PKGBUILD .SRCINFO
    git commit -m "Update to version $LIVE_VERSION (automatic)"
    #git push

    echo "Update complete!"
}

send_healthcheck() {
    local status="$1"
    curl -fsSL "$HEALTHCHECK_URL/$status" >/dev/null
}

main() {
    get_aur_version
    get_live_version

    if [[ "$AUR_VERSION" == "$LIVE_VERSION" ]]; then
        echo "No update needed."
        send_healthcheck "success"
        exit 0
    fi

    echo
    echo "New version detected!"
    echo "Upstream: $LIVE_VERSION"
    echo "AUR:      $AUR_VERSION"
    echo

    send_healthcheck "start"
    do_update
    send_healthcheck "success"
}

main
