#!/usr/bin/env bash

# Get versions
jsfile=$(curl -fsSL -H "Cache-Control: no-cache" https://ksa-archive.net \
  | grep -oP 'src="/assets/\Kindex-[^"]+')
upstream_version=$(curl -fsSL -H "Cache-Control: no-cache" "https://ksa-archive.net/assets/$jsfile" \
  | grep -oP 'setup_ksa_v\K[0-9.]+(?=\.tar\.gz)' \
  | tac \
  | head -n 1)
aur_version=$(curl -fsSL https://aur.archlinux.org/packages/kittenspaceagency-bin | grep "Package Details:" | grep -oP '(?<=kittenspaceagency-bin )[0-9.]+')

# Healthcheck URL
KSA_HC="https://hc-ping.com/869beb5e-c8ce-4ac1-ad64-5c6c869fb44c"

# Delete any old version
# This is mostly just in case a directory is left behind for whatever reason
rm -rf ~/.tmp/kittenspaceagency-bin

if [[ "$aur_version" == "$upstream_version" ]]; then
	curl -fsSL "$KSA_HC" > /dev/null  # Send success signal
	exit
elif [[ "$aur_version" != "$upstream_version" ]]; then
	
	echo "New version detected!"
	echo "Upstream: $upstream_version"
	echo "AUR:      $aur_version"
	echo

	curl -fsSL "$KSA_HC/start"  # Send start signal

	mkdir -p ~/.tmp
        cd ~/.tmp

        git clone ssh://aur@aur.archlinux.org/kittenspaceagency-bin.git
        cd kittenspaceagency-bin

        sed -i "s/^pkgver=.*/pkgver=${upstream_version}/" PKGBUILD
        updpkgsums
        makepkg --printsrcinfo > .SRCINFO

        git add PKGBUILD .SRCINFO
        git commit -m "Updated version."
        git push

	msg="Updated version $aur_version -> $upstream_version"

	echo "$msg"
	curl -fsSL --data-raw "$msg" "$KSA_HC"  # Send success signal

	rm -rf ~/.tmp/kittenspaceagency-bin
	exit

fi

rm -rf ~/.tmp/kittenspaceagency-bin

echo "Update failed!"
curl -fsSL "$KSA_HC/fail"  # Send failure signal
