# PozBookOS

Arch Linux ARM distribution optimized for the Lenovo ThinkPad X13s (Snapdragon 8cx Gen 3 / SC8280XP). Ships a custom kernel built with Clang/LLVM ThinLTO, a Sway desktop, and system-level tuning for ARM big.LITTLE on a laptop.

## Kernel

Based on Linux 7.1.5 stable with the 256-patch X13s series from [steev's branch](https://github.com/steev/linux/tree/lenovo-x13s-linux-7.0.y), forward-ported to 7.1.

Every patch applies to a pristine `v7.1.5` with plain `patch -Np1` and the config is Kconfig-consistent: `make olddefconfig` is a no-op on it, and the build refuses to proceed if that stops being true.

| Feature | Detail |
|---|---|
| Compiler | Clang/LLVM with `-mcpu=cortex-x1c` tuning |
| ThinLTO | Whole-program link-time optimization (+5-12% throughput) |
| CFI | Clang Control Flow Integrity (forward-edge protection) |
| Shadow Call Stack | Return address protection (ARM64 hardware-backed) |
| sched_ext | BPF scheduler extensions (`CONFIG_SCHED_CLASS_EXT`; needs a scheduler from `scx-scheds` to do anything at runtime) |
| DAMON | Data Access Monitoring with proactive reclaim and LRU sort |
| MGLRU | Multi-Gen LRU page replacement |
| Lazy preemption | Better throughput with comparable interactivity |
| ZRAM | LZ4 primary + ZSTD secondary multi-comp, 50% of RAM |
| Thermal governor | power_allocator PID controller (+5-15% sustained perf) |
| BBR + fq | TCP congestion control optimized for WiFi (`CONFIG_DEFAULT_BBR`) |
| PCIe ASPM | Power supersave for NVMe and WiFi |
| CPU idle | TEO governor for deeper C-states |
| NUMA disabled | Removed — SC8280XP is UMA (saves per-CPU overhead) |
| NR_CPUS=8 | Exact core count instead of default 512 |
| Iris VPU | Hardware H.264/H.265/VP9 decode via the SC8280XP video accelerator |
| BTI | Branch Target Identification enabled for the kernel |
| Module compression | ZSTD-compressed modules (~100-300 MB disk savings) |

Required boot parameters: `clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime`

> `efi=noruntime` is only needed on older Lenovo firmware. With a recent UEFI and
> "Linux Boot" enabled in the BIOS it can be dropped, which is what makes
> `efibootmgr` and `bootctl` usable during installation.

## Building

The ISO is built by CI, not locally: `profiles/x13s/pacman.conf` deliberately has
no repository providing `linux-x13s`. `.github/workflows/iso.yaml` builds (or
downloads) the kernel package and injects it as a local repo before running
`mkarchiso`. `container/Dockerfile` pins archiso to an exact version and applies
`container/archiso-dtb-support.patch`, which teaches mkarchiso to substitute
`%DTB%` and to copy the device tree onto the ISO and the EFI system partition --
upstream archiso has no notion of a device tree, and an X13s cannot boot without
one.

## Image

Live/installer ISO with Sway/Wayland desktop. SquashFS compressed with zstd level 19.

| Feature | Detail |
|---|---|
| Desktop | Sway + Waybar + foot + wofi + mako (installed, not preconfigured -- the live session drops to a TTY) |
| Browser | Firefox |
| Audio | PipeWire + WirePlumber with codec power-save |
| GPU | Mesa/Turnip Vulkan 1.3 (Adreno 690) |
| Video decode | GStreamer + mpv on the Iris V4L2 M2M decoder |
| Camera | libcamera (software ISP) + pipewire-libcamera for the ov5675 |
| WiFi | iwd with 5/6 GHz band preference and roam tuning |
| Networking | systemd-networkd, BBR, TCP Fast Open, WiFi buffer tuning |
| Memory | ZRAM (LZ4+ZSTD), MGLRU, DAMON reclaim, 64KB mTHP |
| I/O scheduler | none for NVMe, BFQ for eMMC |
| Containers | Podman 5.x + Buildah (rootless) |
| Security | AppArmor, restricted unprivileged BPF/userfaultfd |
| Power | irqbalance, powertop, timer migration disabled, WiFi PS |
| OOM protection | earlyoom |
| Module blacklist | Unused x86 drivers stripped (i915, amdgpu, iwlwifi, etc.) |
| CLI tools | bat, eza, fd, fzf, ripgrep, btop, jq, ncdu |
| Filesystem | btrfs, f2fs, LUKS, LVM, exFAT, NTFS |

## Boot instructions

1. Download the ISO from [Releases](https://github.com/poz1/PozBookOS/releases)
2. Flash to USB: `dd bs=4M if=archlinux-x13s-*.iso of=/dev/sdX conv=fsync oflag=direct status=progress`
3. Reboot, press F12 at the Lenovo logo, select USB

## Credits

| Project | Link |
|---|---|
| Arch Linux ARM | https://archlinuxarm.org |
| steev's X13s kernel | https://github.com/steev/linux/tree/lenovo-x13s-linux-6.18.y |
| ironrobin's X13s packages | https://github.com/ironrobin/x13s-alarm |
| Linux stable | https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git |
| Arch Linux archiso | https://gitlab.archlinux.org/archlinux/archiso |
