#!/usr/bin/env bash

# Get versions
jsfile=$(curl -fsSL https://ksa-archive.net \
  | grep -oP 'src="/assets/\Kindex-[^"]+')
upstream_version=$(curl -fsSL "https://ksa-archive.net/assets/$jsfile" \
  | grep -oP 'setup_ksa_v\K[0-9.]+(?=\.tar\.gz)' \
  | tac \
  | head -n 1)
aur_version=$(curl -fsSL https://aur.archlinux.org/packages/kittenspaceagency-bin | grep "Package Details:" | grep -oP '(?<=kittenspaceagency-bin )[0-9.]+')

if [[ "$aur_version" != "$upstream_version" ]]; then
	
	echo "New version detected!"
	echo "Upstream: $upstream_version"
	echo "AUR:      $aur_version"
	echo

        cd ~/.tmp
        git clone ssh://aur@aur.archlinux.org/kittenspaceagency-bin.git
        cd kittenspaceagency-bin

        sed -i "s/^pkgver=.*/pkgver=${upstream_version}/" PKGBUILD
        updpkgsums
        makepkg --printsrcinfo > .SRCINFO

        git add PKGBUILD .SRCINFO
        git commit -m "Updated version."
        git push

fi

rm -rf ~/.tmp/kittenspaceagency-bin
