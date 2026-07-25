# Upstream state — survey of 2026-07-25

A dated snapshot of what exists upstream versus what this repository ships, so
that the next person does not repeat the search. Every claim here was checked
against a package database, a git API or an upstream file — not from memory.

Re-read this before a kernel rebase or a package sweep. Items are grouped by
what to do with them, and the "already current" section exists so that things
already verified are not checked twice.

---

## 1. Taken

| What | Source | Why |
|---|---|---|
| PipeWire `quantum = 1024` drop-in | postmarketOS `device-lenovo-21bx/pipewire.conf` | audio pops and clicks |
| `dma_heap` udev rules for libcamera | Void `x13s-base/95-libcamera-hack.rules` | camera for a non-root user |
| `hwdec=auto-safe` in `/etc/mpv/mpv.conf` | — | the Iris decoder was enabled and unreachable |
| Bluetooth address unit | jhovold wiki (`btmgmt public-addr`) | controller came up as `00:00:00:00:00:00` |
| `iwd AddressRandomization=disabled` | — | it stacked a second unstable MAC on an already unstable one |
| `gst-plugin-libcamera` | ALARM `extra` | lets the camera chain be isolated instead of guessed at |

## 2. Deliberately not taken

### Linux 7.2

7.2-rc4 was released 2026-07-19; the final is not out. We ship 7.1.5, which
**is** the latest of the 7.1 series (2026-07-24). 7.0 went EOL at 7.0.14.

At least **35 of our 256 patches are already in 7.2** and would disappear —
about 14% less out-of-tree surface. Groups: BT RFA supply name and WCN power
grid (8), Iris encoder / 10-bit decode / bindings (15), irqchip PDC driver (4),
PCI qcom L1SS and `T_POWER_ON` (2), pinctrl lpass-lpi (2), tsens (2), sc8280xp
dts (2).

**The trap:** the PDC series went in *partially*. Four driver patches are in
7.2; the ~25 device-tree patches that fix the PDC `reg` size across Qualcomm
SoCs are not. At rebase time the series can neither be kept nor dropped
wholesale — the dts half still applies while the driver half conflicts. That is
the failure mode that breaks a rebase quietly.

**Re-check when:** 7.2 final is out *and* steev opens a `lenovo-x13s-linux-7.1.y`
or `7.2.y`. Forward-porting 221 patches by hand without a reference branch is
not worth it.

### archiso v89

`extra/archiso` is still 88-1 (built 2026-03-27), which is what
`container/Dockerfile` pins and checksums. Upstream tagged **v89 on 2026-07-25**
but it is not packaged yet.

**When it is packaged, `container/archiso-dtb-support.patch` will not apply.**
Verified empirically: 8/8 hunks apply to v88, but against v89 hunk #8 fails —
commit `de9c6bbbd` ("mkarchiso: reduce the number of mcopy calls") reworked the
`efiboot_files` array that hunk touches. That hunk is what accounts for the dtb
in the ESP size calculation; without it the FAT image can be undersized and the
dtb `mcopy` fails, which means an ISO with no device tree, which means an X13s
that does not boot. Do not bump archiso without redoing that hunk.

The v89 changelog is otherwise irrelevant to us: non-root `unshare`, x86 releng
profile changes, `install_dir` validation.

### dtbloader

[TravMurav/dtbloader](https://github.com/TravMurav/dtbloader) 1.5.4 (2026-04-05,
repo active). An EFI driver with explicit "Lenovo ThinkPad X13s Gen 1" support:
it reads the **factory WiFi MAC and Bluetooth address from the laptop's DPP
partition** and fixes them into the device tree. postmarketOS depends on it.

This is the real fix for the two most annoying quirks of the machine — the
random MAC and the null BD address — with the *actual* addresses rather than
generated ones. We currently work around both in userspace instead.

Not taken because it replaces how the device tree reaches the kernel: adopting
it means dropping `dtb=` from the command line (dtbloader would install its own
DTB and the stub's would override the fixups) and reworking the boot path. It
is a decision, not a patch.

### stubble / archiso MR !449

MR [!449](https://gitlab.archlinux.org/archlinux/archiso) "add stubble for
aarch64 profiles", opened 2026-07-17, still open. If merged, archiso gains
proper aarch64 device tree handling and **our local patch becomes unnecessary**
— and the same ISO would boot on more than just the 21BX.

Blocked today: `stubble` is in neither `extra` nor ALARM. **Re-check monthly.**

### systemd UKI hwids

systemd >= 260 already ships
`/usr/lib/systemd/boot/hwids/aa64/sc8280xp-lenovo-thinkpad-x13s-21bx.json`
(plus `-21by` and `-4810`). A UKI built with `ukify` would find the right DTB by
itself and cover all three variants. This is the other path to deleting our
archiso patch, and it is a boot architecture change, not a tweak.

## 3. Already current — do not re-check

### Kernel sources

- **steev/linux**: `lenovo-x13s-linux-7.0.y` head is `arm64: dts: qcom:
  sc8280xp-x13s: Use predefined MCLK pinctrl` (2026-06-29). Our last patch is
  that same commit. **There is not one commit of steev's we are not carrying.**
  No `7.1.y` or `7.2.y` branch exists.
- **steev T14s branches** do not anticipate this time: `lenovo-t14s-linux-7.0.y`
  is at 2026-06-10, three weeks behind the X13s branch.
- **jhovold/linux**: newest `wip/sc8280xp` branch is `6.16`, head 2025-07-28 —
  **twelve months old**. The [X13s wiki](https://github.com/jhovold/linux/wiki/X13s)
  is equally frozen, HEAD `fba992f7` 2025-07-28. Treat it as a historical
  document, not as the state of the art: several of its "known issues" are
  things this image already fixes.

### Video

- Mainline 7.2-rc4 does **not** have the SC8280XP Iris enablement. We are ahead
  of mainline here, not behind.
- Iris AV1 exists only as a stateful decoder in patchsets still in review.
- `libva-v4l2-request` does not exist in Arch or the AUR — there is no VA-API
  shim over V4L2 to add.

### Firmware

- `linux-firmware` / `linux-firmware-qcom` are at 20260622-1 on both Arch and
  ALARM. **No 2026 updates to any `sc8280xp/LENOVO/21BX` blob**; the most recent
  touch is `audioreach-tplg.bin` on 2025-10-17.
- `qcvss8280.mbn` has been public since the 2025-05-28 commit "qcom: sc8280xp:
  FW blob updates for X13s". `PATCH-AUDIT.md` claimed otherwise and has been
  corrected.
- The Bluetooth board files (`hpbtfw21.tlv`, `hpnv21.b8c`, `hpnv21g.b8c`) ship
  in `linux-firmware-atheros`, which `linux-firmware` depends on. Also corrected.

### Userspace

The whole of `packages.aarch64` was compared by diffing the ALARM aarch64
core/extra databases against Arch's. **Full parity.** The single difference in
~130 packages is `foot 1.27.0-1` against Arch's `1.27.0-2` — a rebuild, not a
version.

Notable: `alsa-ucm-conf` is 1.2.16.1 on both, which **contains the fix** for the
1.2.14 microphone regression the jhovold wiki still warns about. Do not pin it
to 1.2.13. `scx-scheds` 1.1.2 is the latest upstream release. `systemd` 261.2
was built the same day it was tagged upstream.

### Other X13s projects

- **hanthor/bonito-x13s**: moved to `tuna-os/bonito-x13s` and **archived**.
- **ironrobin/archiso-x13s**: active (last push 2026-07-20) but uses exactly our
  DTB approach — nothing better to take. It forks all of mkarchiso into the
  repository; patching the package, as we do, is more maintainable.
- **aarch64-laptops/build**: alive but working on other machines.
- Live: postmarketOS `pmaports` (device-lenovo-21bx), Void `x13s-base`, the
  Fedora wiki. Those three plus dtbloader are the only sources worth re-reading.

## 4. Still unsolved by anyone

Do not spend time looking for a fix; nobody has one.

- **Speaker volume ceiling.** Deliberate, and it lives in the qcom ASoC machine
  driver. Active speaker protection is unimplemented; no work in progress.
- **Suspend with an external display** connected or disconnected around the
  transition can break resume.
- **USB-C cold-boot orientation detection.** Flip the cable.
- **DisplayPort MST** is absent from drm/msm entirely — one dock, one screen.

## 5. Open questions for this repository

- `CONFIG_VIDEO_QCOM_VENUS=m` is enabled alongside `CONFIG_VIDEO_QCOM_IRIS=m`.
  Venus is the older driver for the same hardware. Only one should bind — decide
  which and drop the other.
- `linux-firmware` pulls in `linux-firmware-amdgpu`, `-nvidia`, `-radeon`,
  `-intel`, `-broadcom`, `-mediatek` by dependency. On a Qualcomm laptop that is
  a large amount of ISO that will never be loaded. Shipping only `-qcom`,
  `-atheros` and `-realtek` would need measuring against the risk of a USB
  device whose firmware is then missing.
- **Nothing here has been built or booted.** The kernel and the ISO have not
  been compiled; hardware video decode in particular is shipped but unverified.
  `v4l2-ctl --list-devices` on the machine is the first thing to run.

## 6. Lenovo UEFI firmware

Latest is **N3HUJ25W, version 1.67, 2026-01-29** (Lenovo's own catalogue). It is
not on LVFS and will not be: the Lenovo maintainer closed the request. Void
gives 1.59 as the practical minimum.

This matters because `efi=noruntime` — which we pass unconditionally and which
makes `efibootmgr` and `bootctl` unusable during installation — is only needed
on older firmware. None of the three active X13s distributions pass it any more.
With recent firmware and "Linux Boot" enabled in the BIOS it can be dropped,
which is what unblocks writing an NVRAM boot entry at install time. Dropping it
blindly on the default is not safe; documenting the requirement is the first
step.
