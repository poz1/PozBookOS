FROM scratch
ADD ArchLinuxARM-aarch64-latest.tar.gz /

# Init pacman keyring and disable Landlock sandbox (unavailable in containers)
RUN sed -i 's/^#\?DisableSandbox/DisableSandbox/' /etc/pacman.conf \
    && grep -q '^DisableSandbox' /etc/pacman.conf || echo 'DisableSandbox' >> /etc/pacman.conf \
    && pacman-key --init \
    && pacman-key --populate archlinuxarm \
    && pacman -Syu --noconfirm

# Install kernel build dependencies
RUN pacman -S --noconfirm \
    base-devel bc clang docbook-xsl dtc git inetutils kmod lld llvm libelf openssl perl python uboot-tools xmlto

# Install archiso (arch=any, not in ALARM repos — fetch from official Arch mirrors)
RUN curl -Lo /tmp/archiso.pkg.tar.zst "https://archlinux.org/packages/extra/any/archiso/download/" \
    && pacman -U --noconfirm /tmp/archiso.pkg.tar.zst \
    && rm /tmp/archiso.pkg.tar.zst

# Create builder user for makepkg
RUN useradd -m builder

# Clean pacman cache to reduce image size
RUN pacman -Scc --noconfirm
