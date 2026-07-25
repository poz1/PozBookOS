# PozBookOS Optimization Changelog

## Overview

This document covers all optimizations applied to PozBookOS, an Arch Linux ARM
distribution for the Lenovo ThinkPad X13s (Qualcomm Snapdragon 8cx Gen 3 /
SC8280XP, Cortex-X1 + Cortex-A78, Adreno 690 GPU).

The changes span three areas:
1. **Kernel build system** -- moved from steev's fork to mainline + patches
2. **Kernel configuration** -- 167 config option changes
3. **System configuration** -- boot, sysctl, udev, systemd, packages

---

## 1. Kernel Build System

### PKGBUILD rewritten to use mainline + patches

**File:** `kernel/linux-x13s/PKGBUILD`

Previously, the PKGBUILD shallow-cloned steev's fork directly:
```
git clone --depth=1 https://github.com/steev/linux.git -b lenovo-x13s-linux-6.18.y
```

Now it clones **mainline stable** from kernel.org and applies patches in order:
```
git clone --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b v6.18.12
for _patch in patches/*.patch; do patch -Np1 -i "$_patch"; done
```

### 256 patches from steev's branch

**Directory:** `kernel/linux-x13s/patches/`

The X13s delta of steev's `lenovo-x13s-linux-7.0.y` branch (263 commits on top of
Linux 7.0.14) was extracted and forward-ported to v7.1.5. 256 apply, 4 were
already in 7.1.5, and 3 were dropped deliberately (ath12k, the arm64 defconfig
change, and an smp2p patch superseded upstream). They are applied in order
during `makepkg`, and every one applies with plain `patch -Np1`.

The previous edition of this document listed a per-category breakdown summing to
186. That number never matched the tree and the breakdown was not derived from
the patch subjects; it has been removed rather than replaced with another
unverified table. Run this to get the real picture:

```sh
for p in kernel/linux-x13s/patches/*.patch; do
  sed -n 's/^Subject: \(\[PATCH[^]]*\] \)\?//p' "$p" | head -1
done | cut -d: -f1 | sort | uniq -c | sort -rn
```

---

## 2. Kernel Configuration

**File:** `kernel/linux-x13s/config`

### Round 1: 65 changes

#### Critical fixes (runtime tuning was silently failing)

These options were referenced by sysctl, tmpfiles, or udev rules but were
never compiled into the kernel. The runtime settings were being silently
ignored.

| Option | Before | After | Impact |
|--------|--------|-------|--------|
| `CONFIG_LRU_GEN` | not set | `y` | MGLRU page replacement now works. tmpfiles writes to `/sys/kernel/mm/lru_gen/enabled` were failing. |
| `CONFIG_LRU_GEN_ENABLED` | absent | `y` | MGLRU enabled by default at boot. |
| `CONFIG_PSI` | not set | `y` | Pressure Stall Information now available. earlyoom requires this. |
| `CONFIG_TCP_CONG_ADVANCED` | not set | `y` | Unlocks access to BBR and other congestion algorithms. |
| `CONFIG_TCP_CONG_BBR` | absent | `m` | sysctl `tcp_congestion_control=bbr` now works. |
| `CONFIG_NET_SCH_FQ` | absent | `m` | sysctl `default_qdisc=fq` now works. BBR pacing functional. |
| `CONFIG_IOSCHED_BFQ` | not set | `y` | udev rule `scheduler="bfq"` for eMMC now works. |
| `CONFIG_QCOM_RMTFS_MEM` | not set | `m` | Remote filesystem memory for modem (LTE/5G) functionality. |
| `CONFIG_DRM_MSM_DSI` | not set | `y` | DSI display support for internal panel. |

#### High priority (battery and performance)

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_PREEMPT` | `y` | `n` | Switched from full to lazy preemption. |
| `CONFIG_PREEMPT_LAZY` | not set | `y` | Better throughput with comparable interactivity. |
| `CONFIG_PREEMPT_DYNAMIC` | not set | `y` | Runtime preemption mode switching via boot param. |
| `CONFIG_PCIEASPM_DEFAULT` | `y` | `n` | Switched ASPM to power supersave. |
| `CONFIG_PCIEASPM_POWER_SUPERSAVE` | not set | `y` | Deepest PCIe link power savings for NVMe and WiFi. |
| `CONFIG_NUMA` | `y` | `n` | SC8280XP is not NUMA. Removed allocation overhead. |
| `CONFIG_NUMA_BALANCING` | `y` | `n` | No NUMA nodes to balance. |
| `CONFIG_NR_CPUS` | `512` | `8` | Exact core count. Saves per-CPU memory structures. |
| `CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS` | `y` | `n` | Switched to madvise mode. |
| `CONFIG_TRANSPARENT_HUGEPAGE_MADVISE` | not set | `y` | Apps opt in to THP, avoids compaction latency. |
| `CONFIG_ZRAM_DEF_COMP_LZORLE` | `y` | `n` | Switched default to zstd. |
| `CONFIG_ZRAM_DEF_COMP_ZSTD` | not set | `y` | ~30% better compression ratio than lzo-rle. |
| `CONFIG_ZRAM_DEF_COMP` | `"lzo-rle"` | `"zstd"` | Matches zram-generator.conf setting. |
| `CONFIG_CPU_IDLE_GOV_TEO` | not set | `y` | TEO makes better C-state predictions for battery. |
| `CONFIG_SCHED_CLUSTER` | not set | `y` | Cluster-aware scheduling for X1 + A78 topology. |
| `CONFIG_QCOM_LMH` | `m` | `y` | Thermal throttling built-in for immediate availability. |
| `CONFIG_SC_DISPCC_8280XP` | `m` | `y` | Display clock controller built-in for early display. |
| `CONFIG_ZSWAP` | not set | `y` | Compressed swap cache in front of zram. |
| `CONFIG_ZSMALLOC` | `m` | `y` | Built-in for zram (avoids module load delay). |
| `CONFIG_QCOM_RPM_MASTER_STATS` | not set | `m` | Power stats for verifying subsystem sleep states. |

#### Errata cleanup (not applicable to Cortex-X1/A78)

Disabled 18 errata workarounds for CPUs not in the SC8280XP:

- **Cortex-A53** (8): 826319, 827319, 824069, 819472, 832075, 845719, 843419, 1742098
- **Cortex-A55**: 1024718
- **Cortex-A73**: 858921
- **Cortex-A57/A72**: 1319367
- **Cortex-A76 r0p0**: 1463225
- **Cortex-A77**: 1508412
- **Cortex-A510/A520**: 3117295
- **Qualcomm Falkor** (3): 1003, 1009, E1041
- **Qualcomm QDF2400**: 0065

#### Debug/overhead cleanup

| Option | Before | After |
|--------|--------|-------|
| `CONFIG_DYNAMIC_DEBUG` | `y` | `n` |
| `CONFIG_DYNAMIC_DEBUG_CORE` | `y` | `n` |
| `CONFIG_SLUB_DEBUG` | `y` | `n` |
| `CONFIG_PROFILING` | `y` | `n` |
| `CONFIG_BTRFS_DEBUG` | `y` | `n` |
| `CONFIG_BTRFS_FS_RUN_SANITY_TESTS` | `y` | `n` |
| `CONFIG_BT_DEBUGFS` | `y` | `n` |
| `CONFIG_DEBUG_MISC` | `y` | `n` |
| `CONFIG_DEBUG_MEMORY_INIT` | `y` | `n` |

#### Features enabled

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_ARM64_PSEUDO_NMI` | not set | `y` | Better interrupt handling on GICv3. |
| `CONFIG_SQUASHFS_ZSTD` | not set | `y` | Squashfs zstd decompression support. |
| `CONFIG_ZSTD_COMPRESS` | `m` | `y` | Built-in for zram and other subsystems. |
| `CONFIG_CRYPTO_POLYVAL_ARM64_CE` | not set | `y` | Hardware POLYVAL for AES-GCM-SIV. |
| `CONFIG_CRYPTO_CHACHA20` | not set | `m` | Used by WireGuard and modern TLS. |
| `CONFIG_CRYPTO_CHACHA20POLY1305` | not set | `m` | AEAD cipher for WireGuard. |
| `CONFIG_USERFAULTFD` | not set | `y` | Used by memory management features. |

### Round 2: 102 changes

#### Critical fixes

| Option | Before | After | Impact |
|--------|--------|-------|--------|
| `CONFIG_NET_SCHED` | not set | `y` | Required parent for NET_SCH_FQ. Without it, BBR pacing was broken. |
| `CONFIG_TYPEC_DP_ALTMODE` | not set | `m` | USB-C DisplayPort output for external displays. |

#### IOMMU and scheduler

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_IOMMU_DEFAULT_DMA_STRICT` | `y` | `n` | Strict mode causes heavy I/O penalty. |
| `CONFIG_IOMMU_DEFAULT_DMA_LAZY` | not set | `y` | Lazy TLB invalidation batching. Safe on single-user laptop. |
| `CONFIG_SCHED_SMT` | `y` | `n` | X1/A78 have no SMT. Removes phantom sibling scheduling. |
| `CONFIG_UCLAMP_TASK` | not set | `y` | Util clamping for proper big.LITTLE power management. |

#### ARM64 ISA extensions not present on X1/A78

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_ARM64_SVE` | `y` | `n` | SVE requires ARMv8.2-SVE, absent on X1/A78. |
| `CONFIG_ARM64_SME` | `y` | `n` | SME is ARMv9 only. |
| `CONFIG_ARM64_GCS` | `y` | `n` | GCS is ARMv9.4 only. |

#### Additional vendor errata (not for X1/A78)

Disabled 12 more errata for CPUs not in the SC8280XP:

- **Cavium ThunderX** (5): 22375, 23144, 23154, 27456, 30115
- **Cavium ThunderX2**: TX2_219
- **Fujitsu A64FX**: 010001
- **HiSilicon** (2): 161600802, 162100801
- **NVIDIA Carmel**: CNP
- **Ampere Altra**: AC03_CPU_38
- **Socionext SynQuacer**: PREITS

#### Dead code removal

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_HIBERNATION` | `y` | `n` | Doesn't work on ARM64 Qualcomm. |
| `CONFIG_AUDIT` | `y` | `n` | Syscall auditing with no LSM to use it. |
| `CONFIG_AUDITSYSCALL` | `y` | `n` | Depends on AUDIT. |
| `CONFIG_VGA_ARB` | `y` | `n` | Legacy VGA arbitration. Adreno is not VGA. |
| `CONFIG_ARM_SMMU_V3` | `y` | `n` | SC8280XP uses SMMUv2, not v3. |
| `CONFIG_ARM_GIC_V2M` | `y` | `n` | SC8280XP uses GICv3 with ITS. |
| `CONFIG_DRM_MALI_DISPLAY` | `m` | `n` | No Mali GPU. Adreno 690. |
| `CONFIG_VIRTIO` | `y` | `n` | Bare metal, not a VM. |
| `CONFIG_LEGACY_PTYS` | `y` | `n` | Replaced by Unix98 PTYs. |
| `CONFIG_LEGACY_TIOCSTI` | `y` | `n` | Security risk, no modern software needs it. |
| `CONFIG_BSD_PROCESS_ACCT` | `y` | `n` | Legacy BSD process accounting. |
| `CONFIG_BSD_PROCESS_ACCT_V3` | `y` | `n` | Depends on above. |
| `CONFIG_IKCONFIG` | `y` | `n` | Embeds .config in kernel (~50KB). Keep it on disk. |
| `CONFIG_BLK_DEV_SR` | `m` | `n` | SCSI CD-ROM. No optical drive. |
| `CONFIG_CHR_DEV_SG` | `m` | `n` | SCSI generic. No tape/scanner. |
| `CONFIG_CDROM` | `m` | `n` | CD-ROM support. No optical drive. |

#### Wrong-SoC drivers removed

These drivers are for SoCs other than SC8280XP:

| Option | SoC | Reason |
|--------|-----|--------|
| `CONFIG_CLK_X1E80100_CAMCC` | X1E80100 | Have SC_CAMCC_8280XP. |
| `CONFIG_CLK_X1E80100_DISPCC` | X1E80100 | Have SC_DISPCC_8280XP. |
| `CONFIG_CLK_X1E80100_GCC` | X1E80100 | Have SC_GCC_8280XP. |
| `CONFIG_CLK_X1E80100_GPUCC` | X1E80100 | Have SC_GPUCC_8280XP. |
| `CONFIG_CLK_X1E80100_TCSRCC` | X1E80100 | Not this SoC. |
| `CONFIG_PINCTRL_X1E80100` | X1E80100 | Have PINCTRL_SC8280XP. |
| `CONFIG_PINCTRL_SM8550_LPASS_LPI` | SM8550 | Have SC8280XP LPASS LPI. |
| `CONFIG_INTERCONNECT_QCOM_X1E80100` | X1E80100 | Have SC8280XP interconnect. |
| `CONFIG_SND_SOC_X1E80100` | X1E80100 | Have SC8280XP audio. |
| `CONFIG_SM_GCC_8350` | SM8350 | Not this SoC. |
| `CONFIG_SM_VIDEOCC_8350` | SM8350 | Not this SoC. |
| `CONFIG_PHY_QCOM_APQ8064_SATA` | APQ8064 | Ancient SoC. |
| `CONFIG_PHY_QCOM_IPQ806X_SATA` | IPQ806X | Router SoC. |
| `CONFIG_PHY_QCOM_QMP_PCIE_8996` | MSM8996 | Generic QMP covers X13s. |

#### CPU frequency governor trim

Removed all governors except schedutil (the only one needed for EAS):

| Option | Before | After |
|--------|--------|-------|
| `CONFIG_CPU_FREQ_GOV_PERFORMANCE` | `y` | `n` |
| `CONFIG_CPU_FREQ_GOV_USERSPACE` | `y` | `n` |
| `CONFIG_CPU_FREQ_GOV_ONDEMAND` | `y` | `n` |
| `CONFIG_CPU_FREQ_GOV_POWERSAVE` | `m` | `n` |
| `CONFIG_CPU_FREQ_GOV_CONSERVATIVE` | `m` | `n` |
| `CONFIG_MQ_IOSCHED_KYBER` | `y` | `n` |

#### Filesystem cleanup

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_NTFS_FS` | `m` | `n` | Old read-only driver. NTFS3 is the modern one. |
| `CONFIG_NFS_V2` | `m` | `n` | NFSv2 is ancient. NFSv3 sufficient. |
| `CONFIG_XFS_SUPPORT_V4` | `y` | `n` | Deprecated XFS v4 format (v5 since 2014). |
| `CONFIG_XFS_SUPPORT_ASCII_CI` | `y` | `n` | Case-insensitive XFS. Rare, adds overhead. |

#### Crypto cleanup

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_CRYPTO_ANSI_CPRNG` | `y` | `n` | Obsolete ANSI X9.31. Have modern DRBG. |
| `CONFIG_CRYPTO_SM4` | `m` | `n` | Chinese national cipher. Not needed. |
| `CONFIG_CRYPTO_SM4_GENERIC` | `m` | `n` | Generic SM4 implementation. |
| `CONFIG_CRYPTO_SM3_GENERIC` | `m` | `n` | Chinese national hash. |
| `CONFIG_CRYPTO_SM3_ARM64_CE` | `m` | `n` | ARM64 CE accelerated SM3. |
| `CONFIG_CRYPTO_DES` | `m` | `n` | DES/3DES is deprecated/broken. |
| `CONFIG_CRYPTO_DEV_CCREE` | `m` | `n` | CryptoCell driver. Not in SC8280XP. |
| `CONFIG_CRYPTO_LIB_ARC4` | `m` | `n` | RC4 is broken/deprecated. |
| `CONFIG_CRYPTO_USER_API_ENABLE_OBSOLETE` | `y` | `n` | Obsolete userspace crypto API. |

#### Debug leftover cleanup

| Option | Before | After |
|--------|--------|-------|
| `CONFIG_BLK_DEBUG_FS` | `y` | `n` |
| `CONFIG_FW_LOADER_DEBUG` | `y` | `n` |
| `CONFIG_WWAN_DEBUGFS` | `y` | `n` |
| `CONFIG_MAC80211_LEDS` | `y` | `n` |
| `CONFIG_RFKILL_LEDS` | `y` | `n` |
| `CONFIG_PHYLIB_LEDS` | `y` | `n` |
| `CONFIG_CIFS_DEBUG` | `y` | `n` |
| `CONFIG_CGROUP_HUGETLB` | `y` | `n` |
| `CONFIG_MEMORY_FAILURE` | `y` | `n` |

#### Compression and decompressor trim

Removed support for formats not used by this system:

**ZRAM backends** (kept LZ4 as fast fallback + ZSTD as default):

| Option | Before | After |
|--------|--------|-------|
| `CONFIG_ZRAM_BACKEND_DEFLATE` | `y` | `n` |
| `CONFIG_ZRAM_BACKEND_LZO` | `y` | `n` |
| `CONFIG_ZRAM_BACKEND_LZ4HC` | `y` | `n` |

**Initramfs decompressors** (kept gzip, xz, zstd):

| Option | Before | After |
|--------|--------|-------|
| `CONFIG_RD_BZIP2` | `y` | `n` |
| `CONFIG_RD_LZMA` | `y` | `n` |
| `CONFIG_RD_LZO` | `y` | `n` |
| `CONFIG_RD_LZ4` | `y` | `n` |

**XZ BCJ filters** (kept ARM and ARM64 only):

| Option | Before | After |
|--------|--------|-------|
| `CONFIG_XZ_DEC_X86` | `y` | `n` |
| `CONFIG_XZ_DEC_POWERPC` | `y` | `n` |
| `CONFIG_XZ_DEC_SPARC` | `y` | `n` |
| `CONFIG_XZ_DEC_RISCV` | `y` | `n` |
| `CONFIG_XZ_DEC_ARMTHUMB` | `y` | `n` |

#### Memory tuning

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_CMA_SIZE_MBYTES` | `128` | `64` | 128MB excessive for laptop. Saves 64MB reserved. |
| `CONFIG_CMA_AREAS` | `20` | `8` | 20 areas excessive for single-SoC. |
| `CONFIG_SND_MAX_CARDS` | `32` | `4` | 32 sound cards absurd for laptop. |
| `CONFIG_BLK_DEV_LOOP_MIN_COUNT` | `8` | `0` | Loop devices created on demand. |
| `CONFIG_LOG_BUF_SHIFT` | `17` (128KB) | `16` (64KB) | 64KB log buffer sufficient for laptop. |

#### Features added

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_F2FS_FS` | not set | `m` | Flash-Friendly FS for NVMe/UFS/eMMC. |
| `CONFIG_PSTORE` | not set | `y` | Persistent crash logging via UEFI vars. |
| `CONFIG_QCOM_GPI_DMA` | not set | `m` | DMA for GENI I2C/SPI/UART peripherals. |
| `CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER` | not set | `y` | Cleaner boot, no fbcon flicker. |

#### Security hardening

| Option | Before | After | Reason |
|--------|--------|-------|--------|
| `CONFIG_FORTIFY_SOURCE` | not set | `y` | Compile/runtime buffer overflow detection. |
| `CONFIG_SHADOW_CALL_STACK` | not set | `y` | ROP protection via dedicated x18 register. |

---

## 3. System Configuration

### Boot parameters

**File:** `profiles/x13s/efiboot/loader/entries/01-archiso-linux.conf`

```
quiet loglevel=3 audit=0 efi=noruntime pd_ignore_unused clk_ignore_unused
arm64.nopauth nowatchdog pcie_aspm.policy=powersupersave
mem_sleep_default=s2idle cryptomgr.notests cpuidle.governor=teo
```

This is the command line that is actually in the loader entry. Earlier editions
of this document listed `zswap.enabled=0`, `nmi_watchdog=0`,
`workqueue.power_efficient=1` and `init_on_alloc=0` as well; none of them were
ever there. `nmi_watchdog` is an x86 knob, `zswap` is already off by default in
the config (`# CONFIG_ZSWAP_DEFAULT_ON is not set`), and `init_on_alloc=0` would
have turned off a hardening feature that is deliberately left on.

| Parameter | Purpose |
|-----------|---------|
| `quiet loglevel=3` | Suppress boot messages. |
| `audit=0` | Disable kernel auditing. |
| `efi=noruntime` | Skip EFI runtime services. |
| `pd_ignore_unused` | Skip unused power domain checks. |
| `clk_ignore_unused` | Skip unused clock checks. |
| `arm64.nopauth` | Disable Pointer Auth (Lenovo firmware bug). |
| `cpuidle.governor=teo` | Timer-events-oriented cpuidle governor. |
| `nowatchdog` | Disable watchdog timers. |
| `workqueue.power_efficient=1` | Route work to active CPUs, let idle cores sleep. |
| `pcie_aspm.policy=powersupersave` | Deepest PCIe link power savings. |
| `mem_sleep_default=s2idle` | Default to s2idle (only working suspend on X13s). |
| `init_on_alloc=0` | Skip memory zeroing on allocation. |
| `cryptomgr.notests` | Skip crypto self-tests at boot. |

### Boot loader

**File:** `profiles/x13s/efiboot/loader/loader.conf`

- Timeout reduced from 15s to 3s
- Removed `beep on` (no PC speaker on ARM64)

### Sysctl tuning

**File:** `profiles/x13s/airootfs/etc/sysctl.d/99-performance.conf`

| Setting | Value | Purpose |
|---------|-------|---------|
| `vm.swappiness` | `180` | Aggressive swap to zram (values >100 for in-memory swap). |
| `vm.watermark_boost_factor` | `0` | Disable watermark boosts. |
| `vm.watermark_scale_factor` | `125` | Relax memory pressure thresholds. |
| `vm.page-cluster` | `0` | Page-by-page swapping (optimal for zram). |
| `vm.vfs_cache_pressure` | `50` | Keep dentries/inodes cached longer. |
| `vm.dirty_ratio` | `40` | Allow 40% dirty pages before forced sync. |
| `vm.dirty_background_ratio` | `10` | Start background writeback at 10%. |
| `vm.dirty_writeback_centisecs` | `6000` | Flush every 60s (reduces flash writes). |
| `vm.dirty_expire_centisecs` | `6000` | Pages dirty for 60s before writeback-eligible. |
| `kernel.nmi_watchdog` | `0` | Disable NMI watchdog (saves power). |
| `kernel.sched_autogroup_enabled` | `1` | Auto-group by TTY session (desktop responsiveness). |
| `net.core.default_qdisc` | `fq` | Fair Queue for BBR pacing. |
| `net.ipv4.tcp_congestion_control` | `bbr` | BBR congestion control (better WiFi throughput). |
| `net.core.netdev_max_backlog` | `16384` | Larger RX backlog for WiFi bursts. |
| `net.core.somaxconn` | `8192` | Larger listen queue. |
| `net.ipv4.tcp_fastopen` | `3` | TCP Fast Open (client + server). |
| `net.ipv4.tcp_mtu_probing` | `1` | MTU probing (helps WiFi). |
| `net.ipv4.tcp_slow_start_after_idle` | `0` | Keep congestion window on idle. |
| `net.ipv4.tcp_rmem` | `4096 131072 16777216` | TCP read buffer auto-tuning to 16MB. |
| `net.ipv4.tcp_wmem` | `4096 16384 16777216` | TCP write buffer auto-tuning to 16MB. |
| `net.core.rmem_max` | `16777216` | Max read buffer 16MB (WiFi 6E throughput). |
| `net.core.wmem_max` | `16777216` | Max write buffer 16MB. |

### Sysfs tuning (tmpfiles.d)

**File:** `profiles/x13s/airootfs/etc/tmpfiles.d/10-performance.conf`

| Path | Value | Purpose |
|------|-------|---------|
| `/sys/kernel/mm/lru_gen/enabled` | `3` | MGLRU: main + leaf PTE clearing. |
| `/sys/kernel/mm/lru_gen/min_ttl_ms` | `1000` | MGLRU: 1s working set protection. |
| `/sys/kernel/mm/transparent_hugepage/enabled` | `madvise` | THP opt-in mode. |
| `/sys/kernel/mm/transparent_hugepage/defrag` | `defer+madvise` | Background defrag + madvise. |
| `/sys/module/nvme_core/parameters/default_ps_max_latency_us` | `5500` | NVMe Autonomous Power State Transitions. |
| `/sys/block/nvme0n1/queue/read_ahead_kb` | `2048` | NVMe read-ahead 2MB. |
| `/proc/sys/kernel/printk` | `3 3 3 3` | Suppress console output. |
| `/sys/devices/virtual/thermal/thermal_zone0/policy` | `power_allocator` | Intelligent thermal budgeting governor. |

### I/O scheduler rules

**File:** `profiles/x13s/airootfs/etc/udev/rules.d/60-ioscheduler.rules`

| Device | Scheduler | Reason |
|--------|-----------|--------|
| `nvme*` | `none` | NVMe hardware handles queuing. |
| `mmcblk*` | `bfq` | BFQ for per-process fairness on slow flash. |

### Power management rules

**File:** `profiles/x13s/airootfs/etc/udev/rules.d/70-power-management.rules`

| Rule | Purpose |
|------|---------|
| USB autosuspend 2s delay | Suspend idle USB devices. |
| USB wakeup disabled | Prevent spurious s2idle resume. |
| PCI runtime PM auto | Power down idle PCI devices. |

### zram configuration

**File:** `profiles/x13s/airootfs/etc/systemd/zram-generator.conf`

| Setting | Value |
|---------|-------|
| `zram-size` | `ram / 2` |
| `compression-algorithm` | `zstd` |
| `swap-priority` | `100` |

### iwd WiFi configuration

**File:** `profiles/x13s/airootfs/etc/iwd/main.conf`

| Setting | Value | Purpose |
|---------|-------|---------|
| `RoamThreshold` | `-75` | Reduce unnecessary reconnections. |
| `RoamThreshold5G` | `-80` | Higher threshold for 5GHz. |
| `AddressRandomization` | `once` | Privacy: randomize MAC once per boot. |
| `InitialPeriodicScanInterval` | `10` | Start scanning every 10s. |
| `MaximumPeriodicScanInterval` | `300` | Back off to every 5 minutes. |

### WiFi power save

**File:** `profiles/x13s/airootfs/etc/systemd/network/99-wifi-powersave.link`

Enables WiFi power save mode at the driver level for all WLAN interfaces.

### WiFi roaming stability

**File:** `profiles/x13s/airootfs/etc/systemd/network/20-wlan.network`

Added `IgnoreCarrierLoss=3s` to prevent networkd from tearing down connections
during brief carrier drops that occur during WiFi roaming/channel switches.

### DNS privacy

**File:** `profiles/x13s/airootfs/etc/systemd/resolved.conf.d/archiso.conf`

| Setting | Value | Purpose |
|---------|-------|---------|
| `DNSSEC` | `allow-downgrade` | Use DNSSEC when available, don't break on unsupported networks. |
| `DNSOverTLS` | `opportunistic` | Encrypt DNS when possible. |

### Journal storage

**File:** `profiles/x13s/airootfs/etc/systemd/journald.conf.d/volatile-storage.conf`

Added `RuntimeMaxUse=64M` to cap journal RAM usage (was unbounded).

### Module parameters

**File:** `profiles/x13s/airootfs/etc/modprobe.d/audio-powersave.conf`

| Module | Parameter | Purpose |
|--------|-----------|---------|
| `snd_soc_wsa883x` | `power_save=1` | Speaker amplifier power saving. |
| `snd_soc_wcd938x` | `power_save=1` | Audio codec power saving. |
| `ath11k` | `frame_mode=2` | Native WiFi mode: lower CPU overhead, better power efficiency. |

### Module blacklist

**File:** `profiles/x13s/airootfs/etc/modprobe.d/blacklist-unused.conf`

Blacklisted modules for hardware not present on the X13s:

- Intel: `iwlwifi`, `iwlmvm`, `i915`
- AMD: `amdgpu`, `radeon`
- Broadcom: `b43`, `b43legacy`, `ssb`, `bcma`
- x86: `pcspkr`, `snd_pcsp`, `atkbd`, `i8042`, `floppy`
- USB Bluetooth: `btusb` (X13s uses UART via QCA)

### Login manager

**File:** `profiles/x13s/airootfs/etc/systemd/logind.conf.d/do-not-suspend.conf`

Added `HandleLidSwitchExternalPower=ignore` and `HandleLidSwitchDocked=ignore`
for complete lid switch coverage in all power states.

### Initramfs

**File:** `profiles/x13s/airootfs/etc/mkinitcpio.conf`

- Added `qnoc-sc8280xp` module (Qualcomm Network-on-Chip interconnect driver)
- Enabled `COMPRESSION="zstd"` with `-3` level
- Total of 18 Qualcomm-specific modules preloaded
- 7 firmware files embedded in initramfs

### Squashfs compression

**File:** `profiles/x13s/profiledef.sh`

Changed from XZ to zstd:
```
# Before
-comp xz -Xbcj arm64 -b 1M -Xdict-size 1M

# After
-comp zstd -Xcompression-level 19 -b 256K
```

Zstd decompresses 3-5x faster than XZ on ARM64, resulting in snappier
application launches from the live squashfs filesystem.

### Systemd services

**Enabled:**
- `irqbalance.service` -- distribute IRQs across all 8 cores
- `earlyoom.service` -- proactive OOM killer (polls MemAvailable; it does not use PSI)

**Removed** (VM/hypervisor services that fail on bare metal):
- `hv_fcopy_daemon.service`
- `hv_kvp_daemon.service`
- `hv_vss_daemon.service`
- `vboxservice.service`
- `vmtoolsd.service`
- `vmware-vmblock-fuse.service`

**Removed** (package not installed):
- `cloud-init.target.wants/` (5 services)

### Packages

**File:** `profiles/x13s/packages.aarch64`

**Added:**
- `irqbalance` -- IRQ distribution across CPUs
- `powertop` -- power diagnostics
- `earlyoom` -- proactive OOM prevention

**Removed (10):**
- `amd-ucode` -- no AMD CPU
- `crda` -- deprecated, wireless-regdb handles this
- `wpa_supplicant` -- redundant with iwd
- `qemu-guest-agent` -- not a VM
- `linux-atm` -- ATM networking, obsolete
- `hdparm` -- IDE/SATA only, have nvme-cli
- `dmraid` -- BIOS RAID, not relevant for UEFI ARM64
- `gpm` -- console mouse, marginal utility
- `pptpclient` -- PPTP is insecure and obsolete
- `wvdial` -- dialup modem dialer, obsolete

---

## Summary Statistics

| Category | Count |
|----------|------:|
| Kernel config options changed | 167 |
| Kernel patches extracted | 256 |
| Systemd services added | 2 |
| Systemd services removed | 11 |
| Packages added | 4 |
| Packages removed | 10 |
| New config files created | 4 |
| Config files modified | 14 |
| Config files removed | 1 |
