#!/usr/bin/env bash

AUR_PKGNAME="kittenspaceagency-bin"
HEALTHCHECK_URL="https://hc-ping.com/869beb5e-c8ce-4ac1-ad64-5c6c869fb44c"

AUR_VERSION=""
LIVE_VERSION=""

get_aur_version() {
    AUR_VERSION=$(curl -fsSL "https://aur.archlinux.org/rpc/?v=5&type=info&arg=$AUR_PKGNAME" | jq -r '.results[0].Version | split("-")[0]')
}

get_live_version() {
    LIVE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/H4ckerxx44/ksa-archive-net/refs/heads/main/public/builds.json | jq -r 'last.linuxFile | capture("(?<ver>\\d+\\.\\d+\\.\\d+\\.\\d+)").ver')

    # Validate version format
    if ! [[ "$LIVE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid upstream version: $LIVE_VERSION"
        send_healthcheck "fail"
        exit 1
    fi
}

do_update() {
    tmpdir=$(mktemp -d --tmpdir="$HOME")
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"

    # Validate proper git clone
    if ! git clone "ssh://aur@aur.archlinux.org/$AUR_PKGNAME.git"; then
        echo "Git clone failed!"
        send_healthcheck "fail"
        exit 1
    fi

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
