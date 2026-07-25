FROM scratch
ADD ArchLinuxARM-aarch64-latest.tar.gz /

# archiso is arch=any and not in the ALARM repos, so it is fetched from the Arch
# archive. Pinned by version AND checksum: the previous floating
# https://archlinux.org/packages/extra/any/archiso/download/ redirect gave a
# different, unverified build on every image rebuild.
ARG ARCHISO_VERSION=88-1
ARG ARCHISO_SHA256=095a453032f0d56c2275db3633c83eeda99bb3416f52f801e2cea5ce180cc56b

# Init pacman keyring and disable Landlock sandbox (unavailable in containers)
RUN sed -i "s/^#\?DisableSandbox/DisableSandbox/" /etc/pacman.conf \
    && grep -q "^DisableSandbox" /etc/pacman.conf || echo "DisableSandbox" >> /etc/pacman.conf \
    && pacman-key --init \
    && pacman-key --populate archlinuxarm \
    && pacman -Syu --noconfirm

# Kernel build dependencies.
#   dwarves -> pahole, required by CONFIG_DEBUG_INFO_BTF; without it Kconfig
#              silently drops BTF and with it CONFIG_SCHED_CLASS_EXT.
#   cpio, rsync, zstd -> used by modules_install / initramfs / module compression.
RUN pacman -S --noconfirm \
    base-devel bc clang cpio docbook-xsl dtc dwarves git inetutils kmod lld llvm \
    libelf openssl perl python rsync uboot-tools xmlto zstd

# archiso, pinned and checksum-verified, plus device tree support.
# Upstream mkarchiso has no notion of a device tree: it substitutes only
# %ARCHISO_LABEL%, %ARCHISO_UUID%, %INSTALL_DIR% and %ARCH% in loader entries and
# copies only vmlinuz-* and initramfs-*.img onto the ISO and the EFI system
# partition. An X13s cannot boot without its .dtb, so we add %DTB% substitution
# and the corresponding copy steps. See container/archiso-dtb-support.patch.
COPY archiso-dtb-support.patch /tmp/archiso-dtb-support.patch
RUN curl -fsSL -o /tmp/archiso.pkg.tar.zst \
      "https://archive.archlinux.org/packages/a/archiso/archiso-${ARCHISO_VERSION}-any.pkg.tar.zst" \
    && echo "${ARCHISO_SHA256}  /tmp/archiso.pkg.tar.zst" | sha256sum -c - \
    && pacman -U --noconfirm /tmp/archiso.pkg.tar.zst \
    && patch -p1 -d / -i /tmp/archiso-dtb-support.patch \
    && bash -O extglob -n /usr/bin/mkarchiso \
    && grep -q "%DTB%" /usr/bin/mkarchiso \
    && rm /tmp/archiso.pkg.tar.zst /tmp/archiso-dtb-support.patch

# Create builder user for makepkg
RUN useradd -m builder

# Clean pacman cache to reduce image size
RUN pacman -Scc --noconfirm
