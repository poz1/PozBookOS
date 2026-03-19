# Kernel Patch Audit Report

Audit of 64 patches in `kernel/linux-x13s/patches/` for the ThinkPad X13s
(Snapdragon 8cx Gen 3 / SC8280XP) on Linux 6.18.12.

---

## Build Toolchain

- **Compiler**: Clang/LLVM with `LLVM=1 LLVM_IAS=1`
- **Target tuning**: `-mcpu=cortex-x1c` (Clang uses NeoverseV1 scheduling model for X1C performance cores)
- **LTO**: ThinLTO (`CONFIG_LTO_CLANG_THIN=y`) — whole-program link-time optimization, ~5-12% improvement over non-LTO builds
- **CFI**: Control Flow Integrity (`CONFIG_CFI_CLANG=y`) — forward-edge control flow protection with <1% overhead on ARM64
- **Shadow Call Stack**: Enabled (`CONFIG_SHADOW_CALL_STACK=y`) — backward-edge return address protection, near-zero overhead on ARM64

**Why Clang over GCC**: GCC maps all SC8280XP cores (both X1C and A78C) to the
same `cortexa57` scheduling model. Clang differentiates: `NeoverseV1` for X1C big
cores and `CortexA57` for A78C little cores. Combined with ThinLTO (not available
with GCC for the kernel), this yields significantly better codegen for big.LITTLE.

---

## Hardware Support Status

### Working

- Internal display (eDP) including backlight control (since 6.3)
- WiFi (ath11k / WCN6855) including power save and ASPM
- Bluetooth (QCA6390 via hci_qca)
- USB-C data and charging (USB-PD since 6.16)
- DisplayPort Alt Mode over USB-C (2-lane only)
- NVMe storage
- UFS storage
- Keyboard, trackpoint, trackpad
- Battery monitoring (qcom_battmgr)
- Speakers (volume-restricted, no active protection driver)
- Headphone jack
- Internal microphone (requires alsa-ucm-conf != 1.2.14)
- CPU frequency scaling (schedutil + qcom-cpufreq-hw)
- Thermal sensors and throttling (TSENS, LMH)
- GPU (Adreno 690) with Mesa/Turnip Vulkan 1.3
- Suspend (s2idle)
- EC integration (patches 0056-0059)
- EFI variables and capsule updates
- Remoteproc (ADSP, CDSP, MPSS) attach/detach

### Not working / Not yet supported

| Feature | Status | Notes |
|---------|--------|-------|
| 4-lane DisplayPort Alt Mode | Not implemented | Only 2-lane works; limits external display resolution/refresh |
| Coldplug USB-C orientation detection | Broken | Orientation only detected on hotplug, not at boot |
| Skin temperature thermal throttling | Not implemented | Chassis temperature is not used as a thermal input; surface can get uncomfortably hot under load |
| Hardware video decode/encode | WIP firmware only | Requires `qcvss8280.mbn` firmware which is not publicly distributed. Iris driver v4 patchset posted upstream March 2026 but not yet merged. |
| Hibernation | Not supported | ARM64 PSCI limitation; no timeline |
| TPM | Not supported | Not exposed by firmware |
| Virtualization (KVM) | Not supported | Firmware does not configure EL2 for Linux |
| Display resume after external display disconnect | Intermittent failure | No upstream fix |
| USB disconnect wakeup | Bug | USB disconnects can trigger spurious wakeups from suspend |
| DisplayPort audio | Not available | DP audio output is unimplemented |
| Speaker full volume | Restricted | Missing active speaker protection driver; volume capped to prevent damage |
| Camera | Intermittent boot failure | Registration race can break boot; hack patch available but not in this set |
| Pops/clicks during audio playback | Known issue | Present on all current kernels |
| Bluetooth range | Limited | Missing board-specific firmware files (`hpbtfw21.tlv`, `hpnv21.b8c`, `hpnv21g.b8c`) |
| WiFi static MAC address | Workaround needed | MAC resets every boot; requires udev rule |

### Required boot parameters

```
clk_ignore_unused pd_ignore_unused arm64.nopauth
```

- `clk_ignore_unused` / `pd_ignore_unused` — firmware leaves clocks/power domains
  running that the kernel does not know about; disabling them crashes the system
- `arm64.nopauth` — firmware does not set up Pointer Authentication keys

`efi=noruntime` may be needed on older UEFI firmware; droppable with newer firmware
that has "Linux Boot" enabled.

### Required userspace

- `linux-firmware >= 20241210`
- `alsa-ucm-conf >= 1.2.11` (avoid 1.2.14, breaks microphones; 1.2.15+ is fine)
- `Mesa >= 23.1.4` (Adreno 690 support)

---

## Kernel Config Performance Impact

Summary of performance impact from hardening and optimization options enabled in
this kernel config. Measured on ARM64 Cortex-X1/A78 cores or derived from upstream
kernel developer benchmarks.

### Options with measurable runtime cost

| Option | Real-world overhead | Synthetic worst-case | Notes |
|--------|-------------------|---------------------|-------|
| `KSTACK_ERASE` | ~1-2% | ~4-5% (hackbench) | Per-syscall kernel stack clearing; mitigated by ARM64 DC ZVA |
| `ZERO_CALL_USED_REGS` | ~1-2% | +5.5% binary size | ARM64 must clear x16/x17 on every function return |
| `INIT_ON_ALLOC_DEFAULT_ON` | ~1% | ~8% (hackbench) | Zero-fills all allocations; ARM64 DC ZVA makes page zeroing nearly free |
| `SECURITY_APPARMOR` | ~0.5-1% I/O-heavy | negligible CPU-bound | Fast-path exit for unconfined processes |
| `RANDSTRUCT_PERFORMANCE` | <0.5% | — | Cache-line-aware struct randomization; minimal vs FULL |
| `AUDIT` + `AUDITSYSCALL` | ~0% (no rules) | ~1-2% with rules | Single branch check per syscall without auditd |

**Combined worst-case for desktop workloads: ~3-5%.**

### Options with net positive performance effect

| Option | Benefit | Notes |
|--------|---------|-------|
| `THERMAL_DEFAULT_GOV_POWER_ALLOCATOR` | +5-15% sustained perf | PID controller prevents over-throttling sawtooth vs step_wise |
| `DEVFREQ_GOV_PASSIVE` | Essential for DDR tracking | Ensures memory bandwidth follows CPU frequency |
| `CGROUP_FREEZER` | Faster suspend/resume | Replaces slower refrigerator mechanism |
| `MODULE_COMPRESS_ZSTD` | Saves ~100-300 MB disk | Boot time neutral (less I/O offsets decompression at ~400 MB/s) |

### Zero-overhead options

All remaining options (SYN_COOKIES, LOCKDOWN_LSM, DMESG_RESTRICT,
RESET_ATTACK_MITIGATION, IO_STRICT_DEVMEM, MSEAL_SYSTEM_MAPPINGS,
EFI_DISABLE_PCI_DMA, INTEGRITY, SYSTEM_BLACKLIST_KEYRING, MAGIC_SYSRQ,
RELAY, SCHED_SMT, DRM_SIMPLEDRM, INPUT_TOUCHSCREEN, MPTCP, MAC80211_LEDS,
THERMAL_NETLINK, THERMAL_STATISTICS, OF_OVERLAY, TASK_DELAY_ACCT) have zero
measurable runtime overhead. They are either dormant until explicitly used,
only run at boot/shutdown, or are behind static branches.

**The thermal governor change alone (+5-15%) more than recovers the combined
hardening cost (-3-5%). Net effect is positive.**

### Advanced optimizations (second pass)

| Option | Category | Expected effect | Notes |
|--------|----------|-----------------|-------|
| `LTO_CLANG_THIN` | Codegen | +5-12% throughput | Whole-program optimization; increases build time significantly |
| `CFI_CLANG` | Security | <1% overhead | Forward-edge control flow integrity; requires LTO |
| `SCHED_EXT` | Scheduler | Enables BPF schedulers | Allows `scx_lavd` for big.LITTLE-aware scheduling; zero overhead when unused |
| `DAMON` + sub-options | Memory | Reduces memory pressure | Proactive reclaim of cold pages based on data access monitoring |
| `DAMON_RECLAIM` | Memory | Reduces swap thrash | Reclaims cold pages before memory pressure builds |
| `DAMON_LRU_SORT` | Memory | Better page aging | Hot/cold page sorting improves LRU decisions |
| `TCP_CONG_BBR` (default) | Network | Better WiFi throughput | BBR v1 handles loss-based congestion better than CUBIC, especially on WiFi |
| `ZRAM_MULTI_COMP` | Memory | Better ZRAM efficiency | LZ4 primary (fast) + ZSTD secondary for idle pages (high ratio) |
| `CRYPTO_ZSTD` + `CRYPTO_LZ4` | Compression | Enables ZRAM/ZSWAP compressors | Required for multi-compression and ZSWAP with ZSTD backend |

### Recommended sysctl tuning (userspace)

These are not kernel config options but recommended runtime parameters for X13s:

```ini
# /etc/sysctl.d/99-pozbook.conf
vm.swappiness = 180                  # aggressive ZRAM usage (with ZRAM, >100 is valid)
vm.watermark_boost_factor = 0        # disable boost for mobile (no NUMA, no THP on ARM64 default)
vm.page-cluster = 0                  # single-page ZRAM I/O (ZRAM random access is fast)
net.ipv4.tcp_congestion_control = bbr  # (also set as kernel default)
net.core.default_qdisc = fq          # required for BBR
```

---

## Patch Notes

### WIP / Hack patches included in this build

| Patch | Label | Risk |
|-------|-------|------|
| 0032 | `wip: firmware: qcom: tzmem: Use self-owner bits` | WIP; may change upstream |
| 0034 | `wip: remoteproc: qcom_q6v5_pas: Avoid using broken reset` | WIP; workaround for firmware limitation |
| 0036 | `hack: soc: qcom: pmic_glink: Avoid platform rpmsg probe race` | Acknowledged hack for race condition |

### Known bugs in applied patches

#### Medium severity

**0008 — drm/dp: clamp PWM bit count**

Only clamps when `bit_count < pn_min`, but never clamps when
`bit_count > pn_max`. The MAX clamping path is unhandled. May cause
incorrect brightness at extreme panel PWM settings.

**0041 — drm/msm: adreno: attach the GMU device to a driver**

- NULL dereference risk in `a6xx_gmu_unbind` / `a6xx_gmu_bind` if
  `priv->gpu` or `priv->gpu_pdev` is NULL
- `pm_runtime_enable()` called in bind but `pm_runtime_disable()` missing
  from error paths
- `of_find_matching_node` result not NULL-checked before passing to
  `of_device_is_available`

**0042 — drm/msm/dpu: Add DSPP GC driver for GAMMA_LUT**

`kzalloc`/`kfree` of ~6 KB `dpu_hw_gc_lut` struct per mixer per atomic
commit in the display hot path. Should be allocated once and reused.
Missing NULL check on `ctl->ops.update_pending_flush_dspp`.

**0059 — platform: arm64: thinkpad-t14s-ec: Add X13s-specific bits**

Shared key events (Fn+4, Fn+Space, trackpoint double-tap) dispatched with
`X13S_EC_KEY_EVT_OFFSET` (0x2000) but keymap entries use
`T14S_EC_KEY_EVT_OFFSET` (0x1000). The codes will never match — these
keys silently do nothing on X13s. Missing `t14s_kbd_bl_update()` call for
Fn+Space means keyboard backlight LED state won't update.

#### Low severity

**0005 — PCI/ASPM: Return enabled ASPM states**

Stub function returns `false` instead of `0` from a `u32` function.

**0043 — wifi: ath11k: Override spammy warn for msdu_done**

Warning suppressed via C comment instead of `ath11k_dbg()` or rate-limiting.

**0061 — drm/msm: always recover the gpu**

Correct fix but no logging when recovery is triggered without pending work —
silent recovery makes debugging harder.

---

## Patch Categories

| Range | Subsystem | Count |
|-------|-----------|-------|
| 0001-0006 | PCI ASPM / ath11k power save | 6 |
| 0007-0008 | DRM panel / DP PWM | 2 |
| 0009 | QRTR MHI synchronization | 1 |
| 0010-0011 | USB Type-C / PMIC GLINK | 2 |
| 0012-0015 | PHY QMP combo DT bindings / USB3+DP lanes | 4 |
| 0016-0018 | Media / V4L2 AV1 | 3 |
| 0019 | DRM connector hw_params | 1 |
| 0020-0025 | SMP2P improvements | 6 |
| 0026-0035 | Remoteproc attach/detach + firmware/DTS | 10 |
| 0036-0039 | RPMSG / QRTR race fixes | 4 |
| 0040 | PCI Qualcomm L1.2 timing | 1 |
| 0041-0042 | DRM MSM Adreno GPU / DPU GAMMA_LUT | 2 |
| 0043-0044 | WiFi / Bluetooth | 2 |
| 0045 | IOMMU SMMU ACTLR | 1 |
| 0046-0048 | DRM MSM DP link / eDP v1.4+ rates | 3 |
| 0049-0050 | ASoC Qualcomm audio | 2 |
| 0051 | RPMh RSC s2idle | 1 |
| 0052 | IOMMU SMMU cleanup | 1 |
| 0053 | DTS BT/RFA supply fix | 1 |
| 0054-0055 | PHY QMP PM runtime | 2 |
| 0056-0059 | ThinkPad EC support | 4 |
| 0060 | Bluetooth HFP offload refactor | 1 |
| 0061 | DRM MSM GPU recovery | 1 |
| 0062-0064 | DTS/clock/PHY misc fixes | 3 |
