# PozBookOS

Arch Linux ARM distribution optimized for the Lenovo ThinkPad X13s (Snapdragon 8cx Gen 3 / SC8280XP). Ships a custom kernel built with Clang/LLVM ThinLTO, a Sway desktop, and system-level tuning for ARM big.LITTLE on a laptop.

## Kernel

Based on Linux 6.18.12 stable with 64 patches from [steev's X13s branch](https://github.com/steev/linux/tree/lenovo-x13s-linux-6.18.y).

| Feature | Detail |
|---|---|
| Compiler | Clang/LLVM with `-mcpu=cortex-x1c` tuning |
| ThinLTO | Whole-program link-time optimization (+5-12% throughput) |
| CFI | Clang Control Flow Integrity (forward-edge protection) |
| Shadow Call Stack | Return address protection (ARM64 hardware-backed) |
| sched_ext | BPF scheduler extensions for big.LITTLE-aware scheduling |
| DAMON | Data Access Monitoring with proactive reclaim and LRU sort |
| MGLRU | Multi-Gen LRU page replacement |
| Lazy preemption | Better throughput with comparable interactivity |
| ZRAM | LZ4 primary + ZSTD secondary multi-comp, 50% of RAM |
| Thermal governor | power_allocator PID controller (+5-15% sustained perf) |
| BBR + fq | TCP congestion control optimized for WiFi |
| PCIe ASPM | Power supersave for NVMe and WiFi |
| CPU idle | TEO governor for deeper C-states |
| NUMA disabled | Removed — SC8280XP is UMA (saves per-CPU overhead) |
| NR_CPUS=8 | Exact core count instead of default 512 |
| Module compression | ZSTD-compressed modules (~100-300 MB disk savings) |

Required boot parameters: `clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime`

## Image

Live/installer ISO with Sway/Wayland desktop. SquashFS compressed with zstd level 19.

| Feature | Detail |
|---|---|
| Desktop | Sway + Waybar + foot + wofi + mako |
| Browser | Firefox |
| Audio | PipeWire + WirePlumber with codec power-save |
| GPU | Mesa/Turnip Vulkan 1.3 (Adreno 690) |
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
