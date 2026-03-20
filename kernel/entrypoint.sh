#!/bin/bash
set -e
cd /build

repo_full=$(cat ./repo)
repo_owner=$(echo $repo_full | cut -d/ -f1)
repo_name=$(echo $repo_full | cut -d/ -f2)

# Configure pacman
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
pacman-key --init
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm --needed sudo git wget python base-devel

# Setup build user
useradd builduser -m
chown -R builduser:builduser /build
git config --global --add safe.directory /build
sudo -u builduser gpg --recv-keys 38DBBDC86092693E
passwd -d builduser
printf 'builduser ALL=(ALL) ALL\n' | tee -a /etc/sudoers

# Import signing keys
cat ./gpg_key | base64 --decode | gpg --homedir /root/.gnupg --import
cat ./gpg_key | base64 --decode | gpg --homedir /home/builduser/.gnupg --import
rm ./gpg_key
echo "checking out buildusers key"
gpg --homedir /home/builduser/.gnupg --list-keys
echo "checking out root key"
gpg --homedir /root/.gnupg --list-keys

# Install Clang/LLVM toolchain, cross-compile support, and kernel build dependencies
# Clang produces better ARM64 code than GCC for SC8280XP (proper NeoverseV1 scheduling
# model for Cortex-X1C cores) and enables ThinLTO for whole-program optimization
pacman -S --noconfirm --needed \
	clang \
	llvm \
	lld \
	aarch64-linux-gnu-binutils \
	aarch64-linux-gnu-gcc \
	bc \
	cpio \
	dtc \
	git \
	inetutils \
	kmod \
	libelf \
	openssl \
	perl \
	python \
	uboot-tools \
	xmlto \
	docbook-xsl

cd linux-x13s

# Check if package was already built in a previous release
already_built=false
for i in $(sudo -u builduser makepkg --packagelist); do
	package=$(basename $i)
	if wget -q https://github.com/$repo_owner/$repo_name/releases/download/packages/$package 2>/dev/null; then
		echo "Warning: $package already built, did you forget to bump the pkgver and/or pkgrel? It will not be rebuilt."
		already_built=true
	fi
done

if [ "$already_built" = false ]; then
	sudo -u builduser bash -c '
		export MAKEFLAGS="-j$(nproc)"
		export CARCH=aarch64
		makepkg --sign -s --noconfirm
	'
fi

cd ..

cp linux-x13s/*.pkg.tar.* ./ || { echo "ERROR: No packages found in linux-x13s/"; exit 1; }
gpg --list-keys
repo-add --sign ./$repo_owner-x13s.db.tar.gz ./*.pkg.tar.zst

for i in *.db *.files; do
	cp --remove-destination $(readlink $i) $i
done
