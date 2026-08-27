# Windows 11 + Arch Linux dual boot with `archinstall` and dotfiles restoration

> **Purpose:** install Arch Linux alongside an existing Windows 11 installation on the same internal SSD, using the official `archinstall` TUI, while preserving Windows, BitLocker recovery capability, the Windows EFI System Partition, and the OEM recovery partitions. The guide then restores the complete workstation described by this repository.
>
> **Read the whole document before changing partitions.** The dangerous steps are clearly marked, but a wrong disk or format operation can destroy data.

---

## Table of contents

1. [Final result](#1-final-result)
2. [Security-state overview](#2-security-state-overview)
3. [Assumptions and safety rules](#3-assumptions-and-safety-rules)
4. [Disk layout and Btrfs design](#4-disk-layout-and-btrfs-design)
5. [Prepare Windows](#5-prepare-windows)
6. [Create and verify the Arch installation USB](#6-create-and-verify-the-arch-installation-usb)
7. [Configure UEFI firmware](#7-configure-uefi-firmware)
8. [Boot and inspect the Arch live environment](#8-boot-and-inspect-the-arch-live-environment)
9. [Install Arch Linux with `archinstall`](#9-install-arch-linux-with-archinstall)
10. [First boot and base-system validation](#10-first-boot-and-base-system-validation)
11. [Configure and repair GRUB](#11-configure-and-repair-grub)
12. [Restore the repository-managed system](#12-restore-the-repository-managed-system)
13. [Enable core services](#13-enable-core-services)
14. [Configure SDDM, Hyprland, and hybrid NVIDIA graphics](#14-configure-sddm-hyprland-and-hybrid-nvidia-graphics)
15. [Timeshift snapshots](#15-timeshift-snapshots)
16. [Validate Windows and restore BitLocker protection](#16-validate-windows-and-restore-bitlocker-protection)
17. [Final validation checklist](#17-final-validation-checklist)
18. [Maintenance: Arch, Windows, BitLocker, Secure Boot, and GRUB](#18-maintenance-arch-windows-bitlocker-secure-boot-and-grub)
19. [Remote access policy](#19-remote-access-policy)
20. [Recovery from the Arch USB and Timeshift](#20-recovery-from-the-arch-usb-and-timeshift)
21. [Troubleshooting](#21-troubleshooting)
22. [References](#22-references)

---

## 1. Final result

The intended machine has:

- Windows 11 preserved on its original NTFS/BitLocker partition.
- Arch Linux as a separate installation on the same GPT disk.
- The original Windows EFI System Partition (ESP) reused **without formatting**.
- A separate 2 GiB ext4 `/boot` partition for Linux kernels, initramfs images, and GRUB files.
- A LUKS2-encrypted Btrfs root partition.
- Manual Btrfs subvolumes:
  - `@` → `/`
  - `@home` → `/home`
  - `@log` → `/var/log`
  - `@pkg` → `/var/cache/pacman/pkg`
- Timeshift selected as the Btrfs snapshot tool in `archinstall`.
- zram instead of an on-disk swap partition.
- `linux` and `linux-lts`.
- GRUB with entries for Arch and Windows Boot Manager.
- A minimal base installation followed by the complete package/configuration deployment from this repository.
- SDDM as the graphical login manager.
- Hyprland as the desktop session.
- Remote desktop deliberately left unconfigured; external KVM hardware such
  as PiKVM is the preferred future approach.

### Why use a separate `/boot`?

Windows often creates an ESP of only a few hundred MiB. This repository installs two kernels, so placing all Linux kernels and initramfs files inside the Windows ESP can eventually exhaust it.

This layout keeps responsibilities separate:

```text
/boot
└── ext4, 2 GiB
    ├── vmlinuz-linux
    ├── vmlinuz-linux-lts
    ├── initramfs-linux.img
    ├── initramfs-linux-lts.img
    └── grub/

/boot/efi
└── existing FAT32 Windows ESP
    └── EFI/
        ├── Microsoft/
        ├── HP/              # or another OEM directory
        └── GRUB/
```

The Windows EFI files remain intact.

---

## 2. Security-state overview

The most important operational rule is to know the intended state of BitLocker, Windows hibernation, Fast Startup, and Secure Boot.

| Phase | BitLocker | Windows hibernation | Fast Startup | Secure Boot |
|---|---|---|---|---|
| Before preparation | Usually **On** | May be enabled | May be enabled | Often enabled |
| Before changing firmware/bootloader | **Suspended**, recovery key saved | **Off** | **Off** | Disable before booting unsigned Arch |
| During Arch installation | **Suspended** | **Off** | **Off** | **Off** |
| During initial dual-boot testing | **Suspended** | **Off** | **Off** | **Off** |
| Stable daily dual boot | **Protection On** | **Off** | **Off** | **Off**, unless a separate signed Secure Boot setup is deliberately implemented |
| Before BIOS/TPM/Secure-Boot changes | **Suspend again first** | **Off** | **Off** | Change only deliberately |
| After firmware changes and validation | **Resume protection** | **Off** | **Off** | Keep the configured state |

### Important distinctions

- **Suspending BitLocker does not decrypt the Windows partition.** It temporarily suspends TPM boot-chain validation.
- **Disabling Windows hibernation is intentional and long-term** for this dual-boot design. It prevents Linux from seeing an NTFS filesystem left in a hibernated state.
- **Fast Startup should remain disabled.** Fast Startup is a form of partial hibernation.
- **Secure Boot stays disabled in this guide.** Do not simply turn it back on after installing Arch: GRUB, kernels, and kernel modules require an explicitly configured signing chain if Secure Boot is to be re-enabled.

---

## 3. Assumptions and safety rules

This guide assumes:

- Windows 11 is already installed.
- The internal disk uses GPT.
- Windows boots in UEFI mode.
- Arch and Windows will share the same physical SSD.
- Windows Disk Management can shrink `C:`.
- The Arch ISO boots in UEFI mode.
- Linux hibernation is not required.
- The user has Internet access and access to this repository.

This guide does **not** cover:

- Legacy BIOS/MBR.
- Intel RST/VMD migration.
- LVM.
- RAID.
- Linux hibernation.
- Secure Boot signing with `sbctl`.
- Replacing Windows.
- Repairing an already-corrupted partition table.

### Non-negotiable safety rules

1. Back up important files before partitioning.
2. Save the BitLocker recovery key outside the computer.
3. Disconnect unrelated storage devices.
4. Keep the laptop on AC power.
5. Use **Manual partitioning** in `archinstall`.
6. Never choose a whole-disk wipe option.
7. Never format the existing Windows ESP.
8. Never delete Windows MSR, Recovery, or OEM partitions.
9. Only the new Arch `/boot` and Arch root partitions are formatted.
10. Review the final `archinstall` preview before pressing Install.
11. If the layout differs from what you expect, cancel instead of guessing.

---

## 4. Disk layout and Btrfs design

A typical final disk resembles:

```text
/dev/nvme0n1
├─p1   512 MiB   FAT32       Windows EFI System Partition   /boot/efi
├─p2    16 MiB               Microsoft Reserved             untouched
├─p3   ... GiB   BitLocker   Windows C:                     untouched
├─p5     2 GiB   ext4        Arch boot                      /boot
├─p6   ... GiB   LUKS2
│ └─dm-0          Btrfs
│   ├─@           /
│   ├─@home       /home
│   ├─@log        /var/log
│   └─@pkg        /var/cache/pacman/pkg
└─p4   ~1 GiB     NTFS       Windows Recovery               untouched
```

Partition numbers can be different. Windows Recovery may remain physically at the end of the disk, so the new Arch partitions can legitimately be created **between** the Windows system partition and the Recovery partition.

### Partition flags

The flags matter:

| Partition | Flags |
|---|---|
| Existing Windows FAT32 ESP | `boot, esp` |
| New ext4 `/boot` | **No ESP flag** |
| New Btrfs/LUKS root | No ESP flag |
| Windows/MSR/Recovery | Leave existing metadata unchanged |

A common `archinstall` mistake is accidentally assigning `boot, esp` to the new ext4 `/boot`. Do **not** leave that flag there. An EFI System Partition is FAT32; the 2 GiB ext4 partition is only the Linux `/boot`.

### Btrfs mountpoints belong to subvolumes

With manual Btrfs partitioning, the large Btrfs partition itself may show a blank `Mountpoint` column. That is normal when its mountpoints belong to Btrfs subvolumes.

The required subvolumes are created manually inside the Btrfs partition:

```text
@       /
@home   /home
@log    /var/log
@pkg    /var/cache/pacman/pkg
```

Do not require an `@snapshots` subvolume for Timeshift. Timeshift manages its own Btrfs snapshot structure.

---

## 5. Prepare Windows

Complete this section entirely from Windows before booting the Arch USB.

### 5.1 Back up data

Back up at least:

- Documents.
- Unpushed repositories.
- Password databases.
- SSH/GPG keys.
- Browser recovery information.
- Application license material.
- BitLocker recovery key.

A Timeshift snapshot created later is **not** a replacement for an external backup.

### 5.2 Update Windows and firmware first

Before modifying the disk:

1. Install pending Windows updates.
2. Install vendor BIOS/UEFI updates if you intend to do so.
3. Restart until Windows is stable.
4. Verify Windows boots normally.

Updating firmware before changing the boot chain reduces the chance that a firmware update later resets or complicates the fresh GRUB configuration.

### 5.3 Verify UEFI and GPT

Press `Win + R`:

```text
msinfo32
```

Confirm:

```text
BIOS Mode: UEFI
```

In Administrator PowerShell:

```powershell
Get-Disk | Format-Table Number,FriendlyName,PartitionStyle,Size
```

The internal system disk should report:

```text
PartitionStyle : GPT
```

Stop if it uses MBR/Legacy boot.

### 5.4 Record BitLocker state and recovery material

Administrator PowerShell:

```powershell
Get-BitLockerVolume
manage-bde -status C:
manage-bde -protectors -get C:
```

Save the 48-digit recovery password somewhere outside the laptop.

Do not proceed if there is no reliable recovery path.

### 5.5 Disable Windows hibernation and Fast Startup

Administrator PowerShell:

```powershell
powercfg.exe /hibernate off
```

This removes the hibernation file and disables hibernation. Fast Startup also depends on this mechanism.

You can inspect the graphical setting at:

```text
Control Panel
→ Hardware and Sound
→ Power Options
→ Choose what the power buttons do
→ Change settings that are currently unavailable
```

Fast Startup should be unavailable or unchecked.

### 5.6 Check the Windows filesystem

```powershell
chkdsk C: /scan
```

Resolve filesystem errors before shrinking `C:`.

### 5.7 Shrink `C:` using Windows Disk Management

Run:

```text
diskmgmt.msc
```

Then:

1. Identify the internal SSD.
2. Right-click `C:`.
3. Choose **Shrink Volume**.
4. Enter the amount to free for Linux.
5. Confirm.
6. Leave the resulting region as **Unallocated**.

Do **not** create a new NTFS volume in that free space.

Do not touch:

- EFI System Partition.
- Microsoft Reserved partition.
- Recovery partition.
- OEM partitions.

Restart Windows once and verify it still boots.

### 5.8 Suspend BitLocker before changing the boot chain

Administrator PowerShell:

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
```

Inspect:

```powershell
Get-BitLockerVolume -MountPoint "C:"
```

The Windows data remains encrypted, but TPM validation is suspended until explicitly resumed.

### 5.9 Perform a full shutdown

```powershell
shutdown /s /f /t 0
```

---

## 6. Create and verify the Arch installation USB

Use the official current Arch Linux ISO and signature file.

### 6.1 Verify the ISO signature

From Linux:

```bash
cd "$HOME/Downloads"

gpg --keyserver-options auto-key-retrieve \
    --verify archlinux-*.iso.sig archlinux-*.iso
```

The important result is:

```text
Good signature from ...
```

GPG may also display:

```text
WARNING: The key's User ID is not certified with a trusted signature!
There is no indication that the signature belongs to the owner.
```

That warning refers to your personal GPG web-of-trust configuration. It does **not** invalidate a cryptographically good signature.

Compare the displayed primary-key fingerprint with the fingerprint published by Arch Linux for the ISO signer.

Do not mark an unfamiliar signing key as `ultimate` merely to suppress the warning.

### 6.2 Identify the USB

```bash
lsblk -p -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL
```

Find a persistent device path:

```bash
ls -l /dev/disk/by-id/usb-*
```

If the USB is currently `/dev/sda`, find the whole-device alias:

```bash
ls -l /dev/disk/by-id/ | grep -E '-> ../../sda$'
```

The persistent path must point to the whole device, not `part1` or `part2`.

Example:

```text
/dev/disk/by-id/usb-SanDisk_3.2Gen1_SERIAL-0:0
```

Assign it:

```bash
USB="/dev/disk/by-id/usb-SanDisk_3.2Gen1_SERIAL-0:0"
```

Verify:

```bash
readlink -f "$USB"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL "$USB"
```

### 6.3 Unmount existing USB partitions

```bash
sudo umount "${USB}-part1" 2>/dev/null || true
sudo umount "${USB}-part2" 2>/dev/null || true
```

A multiboot/YUMI/Ventoy USB will be completely overwritten by the next step.

### 6.4 Write the ISO to the whole USB

**Destructive command: verify `USB` first.**

```bash
sudo dd \
    if="$HOME/Downloads/archlinux-YYYY.MM.DD-x86_64.iso" \
    of="$USB" \
    bs=4M \
    status=progress \
    oflag=direct \
    conv=fsync

sync
```

Afterward a normal Arch ISO may appear similar to:

```text
sda
├─sda1  iso9660  ARCH_YYYYMM
└─sda2  vfat     ARCHISO_EFI
```

That means the USB was written correctly.

Safely eject it:

```bash
sudo eject "$(readlink -f "$USB")"
```

---

## 7. Configure UEFI firmware

Enter the firmware setup or temporary boot menu.

Configure:

- UEFI boot mode: **enabled**.
- Legacy/CSM: **disabled**.
- Secure Boot: **disabled**.
- USB boot: enabled.

Do not:

- Clear the TPM.
- Delete TPM keys.
- Change AHCI/RST/VMD/storage-controller mode blindly.
- Delete Windows Boot Manager.

Choose the USB entry that explicitly boots in UEFI mode.

### Secure Boot note

Leave Secure Boot disabled after installation unless you later build a complete signed Secure Boot chain for GRUB/kernel/modules. Merely re-enabling Secure Boot on this installation can make Arch fail to boot.

---

## 8. Boot and inspect the Arch live environment

### 8.1 Keyboard

For a Spanish keyboard:

```bash
loadkeys es
```

### 8.2 Confirm UEFI boot

```bash
ls /sys/firmware/efi/efivars
```

If the directory does not exist, reboot and choose the UEFI USB entry.

### 8.3 Network

Ethernet:

```bash
ping -c 3 archlinux.org
```

Wi-Fi:

```bash
iwctl
```

Inside:

```text
device list
station DEVICE scan
station DEVICE get-networks
station DEVICE connect NETWORK_NAME
exit
```

Then:

```bash
ping -c 3 archlinux.org
```

### 8.4 Time

```bash
timedatectl set-ntp true
timedatectl status
```

### 8.5 Identify the internal disk

```bash
lsblk -e7 -p \
    -o NAME,SIZE,TYPE,FSTYPE,FSVER,LABEL,PARTLABEL,PARTTYPE,MOUNTPOINTS,MODEL
```

Also:

```bash
fdisk -l
```

`lsblk` shows block devices and partitions, but it does **not** normally display unallocated gaps as a row. Therefore, if the free space created in Windows seems to be missing, inspect it explicitly:

```bash
parted /dev/nvme0n1 unit GiB print free
```

Replace `/dev/nvme0n1` with the verified internal disk.

You should see a large `Free Space` region corresponding to the Windows shrink operation.

Do not proceed until the internal SSD, Windows ESP, Windows partition, Recovery partition, and free region are understood.

### 8.6 Start the installer

```bash
archinstall
```

---

## 9. Install Arch Linux with `archinstall`

Menu wording changes between `archinstall` versions. The required **result** matters more than exact menu labels.

### 9.1 Locale, keyboard, mirrors, and time

Configure:

- Desired installer language.
- Correct keyboard layout.
- UTF-8 locale.
- Correct timezone.
- Automatic NTP synchronization.
- Appropriate mirrors.

### 9.2 Disk configuration: manual layout only

Choose:

```text
Disk configuration
→ Manual partitioning
→ internal Windows SSD
```

Confirm:

```text
Wipe: False
```

The existing Windows partitions must remain marked as existing.

### 9.3 Reuse the existing Windows ESP

Select the existing FAT32 EFI partition.

Set:

```text
Mountpoint: /boot/efi
Format:     NO
Flags:      boot, esp
```

Do not alter its filesystem.

The ESP should remain an **existing** partition.

### 9.4 Leave all other Windows partitions untouched

Do not modify:

- Microsoft Reserved partition.
- Windows/BitLocker partition.
- Windows Recovery partition.
- OEM partitions.

No Linux mountpoint is required for them during installation.

### 9.5 Create the new 2 GiB ext4 `/boot`

Select the free region and create:

```text
Size:       2 GiB
Filesystem: ext4
Mountpoint: /boot
Format:     YES
Flags:      NONE
```

#### Critical flag check

`archinstall` may make it easy to accidentally assign `boot, esp` to `/boot`.

Remove those flags from the ext4 `/boot` partition.

Only the original FAT32 Windows ESP should have:

```text
boot, esp
```

### 9.6 Create the Btrfs root partition

Use the rest of the free space:

```text
Filesystem: btrfs
Format:     YES
```

Do **not** worry if the Btrfs partition itself does not ask for `/` or shows a blank mountpoint. With manual Btrfs configuration, mountpoints belong to the subvolumes.

### 9.7 Create the Btrfs subvolumes manually

Select the new Btrfs partition and enter its Btrfs/subvolume configuration menu.

Create exactly:

| Name | Mountpoint |
|---|---|
| `@` | `/` |
| `@home` | `/home` |
| `@log` | `/var/log` |
| `@pkg` | `/var/cache/pacman/pkg` |

After returning to the partition table, the Btrfs partition can still have a blank `Mountpoint` field while displaying something such as:

```text
4 subvolumes
```

That is correct.

### 9.8 Final partition preview

Before confirming, the conceptual layout must be:

```text
existing FAT32 ESP
    /boot/efi
    boot, esp
    NO FORMAT

existing Windows/MSR/Recovery
    NO FORMAT
    NO DELETE
    NO RESIZE

new 2 GiB ext4
    /boot
    FORMAT
    NO boot/esp flag

new large Btrfs
    FORMAT
    subvolumes:
        @       /
        @home   /home
        @log    /var/log
        @pkg    /var/cache/pacman/pkg
```

A few MiB of free alignment space at the end of the GPT disk is normal.

Select **Confirm and exit** only when this is true.

### 9.9 Encryption

Choose LUKS encryption for **only the new Btrfs partition**.

Do not encrypt:

- Windows ESP.
- Windows.
- `/boot`.
- Recovery.

Use a strong LUKS passphrase. This passphrase is independent of the Linux user password.

### 9.10 Btrfs snapshots

When `archinstall` offers Btrfs snapshot integration, choose:

```text
Timeshift
```

This is easier than manually creating a separate snapshot layout later and works with the `@`/`@home` naming convention.

### 9.11 Bootloader

Select:

```text
GRUB
```

Recommended options:

```text
Unified kernel images:          disabled
Install to removable location:  disabled
Plymouth:                       optional; disabled for the simplest first boot
```

The bootloader menu may **not** ask again where the ESP is. That is expected: the installer already knows the EFI destination because the existing ESP was assigned `/boot/efi` in the disk configuration.

When `Install to removable location` is disabled, GRUB is installed normally with an NVRAM entry.

### 9.12 Swap

Select zram.

No disk swap partition is required.

### 9.13 User and hostname

Create:

- A normal user.
- Administrative/sudo privileges.
- A strong password.

Use a simple hostname such as:

```text
arch-workstation
```

### 9.14 Profile

Select:

```text
minimal
```

Do not install another desktop environment. The repository will install Hyprland and its complete environment.

### 9.15 Kernels

Select:

```text
linux
linux-lts
```

### 9.16 Network

Select NetworkManager.

### 9.17 Multilib

Enable:

```text
multilib
```

The repository uses `lib32-*` packages.

### 9.18 Additional packages

Install a few tools needed **before** the repository installer runs:

```text
git neovim less os-prober fuse3 ntfs-3g
```

Why:

- `git`: clone the dotfiles repository.
- `neovim`: provides `nvim` for editing GRUB/Pacman/mkinitcpio before the full profile is restored.
- `less`: allows package-resolution output to be reviewed interactively.
- `os-prober`: detects Windows.
- `fuse3`: supports filesystem inspection by related tools.
- `ntfs-3g`: helps Windows filesystem detection.

A minimal Arch installation may not contain `nano`, `vi`, or `less`, so installing `neovim` and `less` here avoids confusing `command not found` errors.

### 9.19 Final `archinstall` review

Before Install, verify:

- Correct SSD.
- Manual layout.
- `Wipe: False`.
- Existing Windows partitions preserved.
- Existing FAT32 ESP → `/boot/efi`, no format.
- New ext4 2 GiB → `/boot`, format, **no ESP flag**.
- Large Btrfs root with four subvolumes.
- LUKS only on Btrfs root.
- Timeshift selected.
- zram enabled.
- `linux` + `linux-lts`.
- GRUB.
- Multilib.
- NetworkManager.
- Normal sudo-capable user.

Only then start the installation.

---

## 10. First boot and base-system validation

After installation:

1. Reboot.
2. Remove the USB.
3. Select Arch from the firmware/GRUB entry if necessary.
4. Enter the LUKS passphrase.
5. Log in at the TTY with the normal user.

### 10.1 Validate mount layout

```bash
lsblk -f
findmnt /
findmnt /boot
findmnt /boot/efi
```

Expected:

- `/` → Btrfs inside `/dev/mapper/...`.
- `/boot` → new ext4 partition.
- `/boot/efi` → original FAT32 Windows ESP.

Check subvolumes:

```bash
sudo btrfs subvolume list /
```

Confirm `@`, `@home`, `@log`, and `@pkg` or their paths are present.

### 10.2 Validate both kernels

```bash
pacman -Q linux linux-lts
ls -lh /boot
uname -r
```

Later, test `linux-lts` from GRUB's Advanced Options.

### 10.3 Network

```bash
nmcli device status
ping -c 3 archlinux.org
```

For Wi-Fi:

```bash
nmcli device wifi list
nmcli device wifi connect "NETWORK_NAME" password "NETWORK_PASSWORD"
```

### 10.4 Update the base system

```bash
sudo pacman -Syu
```

Arch does not support partial upgrades. Do not use `pacman -Sy package`.

### 10.5 Confirm Multilib

```bash
pacman-conf --repo-list | grep -x multilib
```

If missing:

```bash
sudo nvim /etc/pacman.conf
```

Uncomment:

```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Then perform a **full** upgrade:

```bash
sudo pacman -Syu
```

---

## 11. Configure and repair GRUB

### 11.1 Verify Windows Boot Manager still exists

```bash
sudo test -f /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi \
    && echo "Windows Boot Manager found" \
    || echo "Windows Boot Manager not found"
```

Also:

```bash
findmnt /boot
findmnt /boot/efi
```

### 11.2 Enable Windows detection

```bash
sudo pacman -S --needed os-prober fuse3 ntfs-3g
sudo nvim /etc/default/grub
```

Ensure:

```ini
GRUB_DISABLE_OS_PROBER=false
GRUB_TIMEOUT=5
```

### 11.3 Detect Windows

```bash
sudo os-prober
```

Expected output contains Windows Boot Manager.

### 11.4 Generate the menu

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Check:

```bash
grep -i windows /boot/grub/grub.cfg
```

### 11.5 If `/boot/grub` is missing

A possible first-install symptom is:

```text
/boot/grub/grub.cfg.new: No such file or directory
```

Do **not** solve this by merely creating an empty `/boot/grub` directory. First verify mounts:

```bash
findmnt /boot
findmnt /boot/efi
ls -la /boot
sudo ls -la /boot/efi/EFI
```

If `/boot` is the new ext4 partition and `/boot/efi` is the original FAT32 ESP, reinstall GRUB cleanly:

```bash
sudo grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --recheck
```

Then:

```bash
ls -la /boot/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
grep -i windows /boot/grub/grub.cfg
sudo efibootmgr -v
```

The ESP should still contain separate directories such as:

```text
EFI/
├── Boot/
├── GRUB/
├── Microsoft/
└── OEM/
```

Never delete `EFI/Microsoft`.

---

## 12. Restore the repository-managed system

The repository defines packages and selected configuration. It is not a backup of personal files, credentials, browser profiles, or secrets.

### 12.1 Clone the repository

```bash
git clone \
    https://github.com/joansr27/dotfiles.git \
    "$HOME/dotfiles"

cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
```

### 12.2 Choose the profile

Examples:

```bash
export PROFILE=omen
```

or:

```bash
export PROFILE=amd-current
```

Check:

```bash
printf 'Selected profile: %s\n' "$PROFILE"
```

### 12.3 Resolve and inspect packages

```bash
cd "$HOME/dotfiles"

./scripts/resolve-packages.sh "$PROFILE" | less
./scripts/validate-packages.sh "$PROFILE"
```

Inside `less`:

```text
q        quit
/word    search
g        beginning
G        end
```

`[END]` means the pager reached the end; the script is not stuck.

The repository supports only packages available from enabled official Arch
Linux repositories.

### 12.4 Run the complete installer

Run as the normal user:

```bash
cd "$HOME/dotfiles"
./install/install.sh "$PROFILE"
```

Do not prepend `sudo`.

The installer:

1. validates that the host is Arch Linux;
2. resolves the selected official package profile;
3. checks Multilib when required;
4. performs a full system update;
5. installs packages through Pacman;
6. selects the machine-specific Hyprland profile;
7. creates required user directories;
8. runs the Stow preflight;
9. deploys the Stow-managed configurations;
10. sets the default applications.

### 12.5 Stow conflicts

If Stow reports an existing target not owned by Stow, back it up instead of using `--adopt` blindly.

Example:

```bash
backup="$HOME/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/waybar" "$backup/waybar-copy" 2>/dev/null || true
mv "$HOME/.config/waybar" "$backup/waybar-original" 2>/dev/null || true
```

Then:

```bash
cd "$HOME/dotfiles"
./scripts/stow-preflight.sh
./install/install.sh "$PROFILE"
```

### 12.6 Validate repository deployment

```bash
cd "$HOME/dotfiles"

./scripts/check-desktop-config.sh
./scripts/stow-preflight.sh
./scripts/validate-packages.sh "$PROFILE"
```

Check machine selection:

```bash
ls -l "$HOME/.config/hypr/machine.conf"
readlink -f "$HOME/.config/hypr/machine.conf"
```

---

## 13. Enable core services

Do this after the repository installer completes.

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now firewalld
sudo systemctl enable --now cronie
sudo systemctl enable --now power-profiles-daemon
```

Remote desktop is intentionally not configured by this installation guide.
External KVM hardware such as PiKVM is the preferred future approach.

Check:

```bash
systemctl --failed
```

---

## 14. Configure SDDM, Hyprland, and hybrid NVIDIA graphics

The simplest supported design is:

- The repository installs `sddm` and `hyprland`.
- SDDM provides the graphical user/password login.
- The standard Hyprland session is selected at the SDDM login screen.
- No custom launcher/session wrapper is required unless a future Hyprland change explicitly makes one necessary.

### 14.1 Confirm the session exists

```bash
pacman -Q sddm hyprland
ls /usr/share/wayland-sessions/
```

A Hyprland desktop entry should be present.

### 14.2 Enable SDDM

```bash
sudo systemctl enable sddm
sudo reboot
```

Expected boot flow:

```text
GRUB
→ LUKS passphrase
→ Arch boot
→ SDDM graphical login
→ user password
→ Hyprland
```

### 14.3 Validate Hyprland after login

```bash
hyprctl configerrors
hyprctl monitors all

cd "$HOME/dotfiles"
./scripts/check-desktop-config.sh
```

### 14.4 Hybrid Intel + NVIDIA: validate DRM

For a hybrid Intel/NVIDIA laptop:

```bash
nvidia-smi

lspci -k | grep -A4 -E 'VGA|3D|Display'

lsmod | grep -E 'i915|nvidia'

cat /sys/module/nvidia_drm/parameters/modeset
```

Modern Arch `nvidia-utils` enables NVIDIA DRM modesetting by default. The last command should normally print:

```text
Y
```

If it already prints `Y`, do not add redundant `nvidia_drm.modeset=1` fixes.

### 14.5 Black screen with cursor before SDDM appears

A hybrid laptop can occasionally reach a black screen with a cursor while TTY access still works.

Switch to a TTY:

```text
Ctrl + Alt + F3
```

Log in and test:

```bash
sudo systemctl stop sddm

cat /sys/module/nvidia_drm/parameters/modeset
nvidia-smi
lspci -k | grep -A4 -E 'VGA|3D|Display'
lsmod | grep -E 'i915|nvidia'

sudo systemctl start sddm
```

If restarting SDDM immediately makes the login screen appear, the graphics stack works and the problem is likely startup timing: SDDM/Xorg started before the hybrid graphics stack was fully ready.

### 14.6 Fix SDDM/NVIDIA startup timing with early module loading

Inspect the initramfs configuration:

```bash
grep -E '^(MODULES|HOOKS)=' /etc/mkinitcpio.conf
```

Edit:

```bash
sudo nvim /etc/mkinitcpio.conf
```

For an Intel iGPU + NVIDIA dGPU laptop, ensure the `MODULES` array loads Intel first, then NVIDIA:

```ini
MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

If `MODULES` already contains required modules, preserve them and add these in the appropriate order rather than deleting existing entries.

Do **not** change `HOOKS` simply to solve this SDDM timing problem.

Regenerate all installed kernel initramfs images:

```bash
sudo mkinitcpio -P
```

The command must finish without errors for both `linux` and `linux-lts`.

Reboot:

```bash
sudo reboot
```

If SDDM now appears normally on cold boot, the timing issue is resolved.

> NVIDIA early loading is particularly appropriate here because Linux hibernation is intentionally not used by this setup.

### 14.7 Monitor configuration

Inside Hyprland:

```bash
hyprctl monitors all
```

Edit only the active machine profile:

```bash
nvim "$HOME/.config/hypr/machines/omen.conf"
```

or the relevant profile.

Apply:

```bash
hyprctl reload
hyprctl configerrors
```

---

## 15. Timeshift snapshots

Timeshift should already have been selected in `archinstall`.

### 15.1 Confirm configuration

```bash
sudo timeshift --list
```

If graphical review is desired:

```bash
sudo timeshift-gtk
```

Use Btrfs mode.

Timeshift is intended for **system rollback**, not personal-data backup.

### 15.2 Create the first known-good snapshot

After Arch, SDDM, Hyprland, graphics, networking, and the repository configuration work:

```bash
sudo timeshift \
    --create \
    --comments "Initial working Arch and Hyprland installation"
```

List:

```bash
sudo timeshift --list
```

### `btrfs: Quotas are not enabled`

Timeshift may print:

```text
btrfs: Quotas are not enabled
```

That is not an error. Btrfs qgroups/quotas are optional and are not required for Timeshift to create or restore snapshots.

Do not enable quotas merely to remove this message.

### 15.3 Before risky changes

Create an on-demand snapshot before:

- Large `pacman -Syu` upgrades.
- Kernel/NVIDIA changes.
- SDDM or display-manager changes.
- Major Hyprland configuration changes.
- Bootloader experiments.

Example:

```bash
sudo timeshift \
    --create \
    --comments "Before kernel and NVIDIA update"
```

### 15.4 LUKS header backup

Timeshift cannot protect against LUKS-header corruption.

Identify the physical encrypted partition:

```bash
lsblk -f
```

Back up its header to an encrypted external disk:

```bash
sudo cryptsetup luksHeaderBackup \
    /dev/ARCH_ROOT_PARTITION \
    --header-backup-file /PATH/ON/EXTERNAL/DISK/arch-luks-header.img
```

Treat that file as sensitive.

---

## 16. Validate Windows and restore BitLocker protection

Boot Windows through GRUB.

### 16.1 Windows Hello PIN may be reset

Changing Secure Boot/TPM boot measurements can cause:

```text
Something happened and your PIN isn't available
```

This does not by itself indicate Windows corruption.

Use:

```text
Set up my PIN
```

and authenticate with the Microsoft/local account as requested.

If available, **Sign-in options** can be used to log in with the account password and recreate the PIN from Windows Settings.

Do **not** clear the TPM as a first-line troubleshooting step.

### 16.2 Validate Windows before resuming BitLocker

Check:

- Files are present.
- `C:` has the expected size.
- Device Manager is healthy.
- Windows Update opens normally.
- Windows can reboot through GRUB.
- Arch also still boots.

### 16.3 Resume BitLocker

Administrator PowerShell:

```powershell
Resume-BitLocker -MountPoint "C:"
```

Then:

```powershell
manage-bde -status C:
```

Desired state:

```text
Conversion Status: Fully Encrypted
Protection Status: Protection On
```

### 16.4 If `Resume-BitLocker` reports missing key protectors

Do not disable/decrypt the volume and do not clear the TPM.

Inspect:

```powershell
Get-BitLockerVolume -MountPoint "C:" |
    Format-List MountPoint,VolumeStatus,ProtectionStatus,EncryptionPercentage,KeyProtector

manage-bde -protectors -get C:

Get-Tpm
```

The TPM should normally report:

```text
TpmPresent : True
TpmReady   : True
```

If the OS volume is missing its TPM protector, add one:

```powershell
Add-BitLockerKeyProtector -MountPoint "C:" -TpmProtector
```

If there is no recovery-password protector, create one:

```powershell
Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
```

Save the newly displayed recovery password **outside the laptop**.

Verify protectors again:

```powershell
manage-bde -protectors -get C:
```

Then:

```powershell
Resume-BitLocker -MountPoint "C:"
manage-bde -status C:
```

Only add protectors that are actually missing.

---

## 17. Final validation checklist

### Storage

```bash
lsblk -f
findmnt /
findmnt /boot
findmnt /boot/efi
sudo btrfs subvolume list /
```

### Boot

```bash
sudo efibootmgr -v
sudo os-prober
grep -i windows /boot/grub/grub.cfg
```

Confirm:

- GRUB NVRAM entry exists.
- Windows Boot Manager still exists.
- Windows appears in `grub.cfg`.
- `linux` boots.
- `linux-lts` boots.

### Repository

```bash
cd "$HOME/dotfiles"
git status
./scripts/validate-packages.sh "$PROFILE"
./scripts/stow-preflight.sh
./scripts/check-desktop-config.sh
```

### Desktop

```bash
hyprctl configerrors
hyprctl monitors all
systemctl status sddm --no-pager
```

### NVIDIA profile

```bash
nvidia-smi
cat /sys/module/nvidia_drm/parameters/modeset
```

### Services

```bash
systemctl --failed
systemctl --user --failed
```

### Audio

```bash
wpctl status
```

### Bluetooth

```bash
bluetoothctl show
```

### zram

```bash
swapon --show
zramctl
```

### Timeshift

```bash
sudo timeshift --list
```

---

## 18. Maintenance: Arch, Windows, BitLocker, Secure Boot, and GRUB

### 18.1 Normal stable state

For ordinary use:

```text
BitLocker:           ON / protection enabled
Windows hibernation: OFF
Windows Fast Startup:OFF
Secure Boot:         OFF
GRUB:                normal default bootloader
```

### 18.2 Arch Linux update workflow

Before a large update:

1. Check Arch Linux News when the system has not been updated recently or fundamental packages are changing.
2. Create a Timeshift snapshot.
3. Ensure there is time to troubleshoot before an important deadline.

Snapshot:

```bash
sudo timeshift \
    --create \
    --comments "Before Arch system upgrade"
```

Update official packages:

```bash
sudo pacman -Syu
```

Never use:

```text
pacman -Sy
pacman -Sy package
```

as a normal update/install workflow. Arch does not support partial upgrades.

After kernel, NVIDIA, systemd, graphics, or display-manager updates, reboot:

```bash
sudo reboot
```

Then check:

```bash
systemctl --failed
systemctl --user --failed
nvidia-smi
cat /sys/module/nvidia_drm/parameters/modeset
```

If Pacman reports `.pacnew` files, review them rather than ignoring them:

```bash
sudo find /etc -name '*.pacnew' -print
```

Use `nvim` to compare/merge relevant configuration.

### 18.3 Windows maintenance

Routine Windows Update can normally be performed with BitLocker protection **On**.

After a major Windows/feature update:

1. Confirm GRUB is still the preferred UEFI entry.
2. Confirm Windows did not re-enable hibernation/Fast Startup.
3. Confirm Arch still boots.

Reassert the intended hibernation state if needed:

```powershell
powercfg.exe /hibernate off
```

### 18.4 BIOS/UEFI/TPM firmware maintenance

Before BIOS, TPM firmware, Secure Boot, or other boot-measurement changes:

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
```

Confirm the recovery key is available.

Perform the firmware update.

Afterward:

1. Confirm Secure Boot remains in the intended state.
2. Confirm GRUB is still available in UEFI.
3. Boot Windows.
4. Boot Arch.
5. Resume BitLocker.

```powershell
Resume-BitLocker -MountPoint "C:"
manage-bde -status C:
```

### 18.5 GRUB configuration maintenance

Edit GRUB defaults with:

```bash
sudo nvim /etc/default/grub
```

After changing `/etc/default/grub`:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Regenerate the GRUB config when:

- `GRUB_*` settings are changed.
- A kernel is added or removed.
- Windows/another OS needs to be rediscovered.
- Arch documentation/news explicitly requires it.

You do **not** need to run `grub-install` after every kernel update.

Reinstall the EFI GRUB binary when:

- `/boot/grub` or the EFI loader is damaged.
- GRUB itself receives an update for which Arch documentation recommends reinstalling.
- The firmware/ESP entry needs reconstruction.

```bash
sudo grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --recheck

sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Always verify:

```bash
sudo test -f /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi \
    && echo "Windows EFI loader intact"

sudo efibootmgr -v
```

### 18.6 If Windows starts directly after an update

A Windows or firmware update can change NVRAM boot order without deleting Arch.

From firmware, select GRUB/Arch manually.

From Arch:

```bash
sudo efibootmgr -v
```

Adjust boot order only after identifying the entry numbers correctly.

---

## 19. Remote access policy

Remote desktop configuration is intentionally outside the scope of this
installation guide.

The preferred architecture is external KVM hardware such as **PiKVM**. This
keeps remote keyboard, video, and mouse access separate from the Arch desktop
software stack.

PiKVM setup, networking, authentication, and operating procedures will be
documented separately after the hardware workflow has been tested.

The workstation profile currently retains:

```text
tailscale
wayvnc
```

Both are official Arch packages kept as optional software building blocks.

This repository currently does **not**:

- configure WayVNC;
- enable WayVNC as a remote-desktop service;
- configure Tailscale for remote desktop;
- create remote-access credentials;
- provide remote-on or remote-off helper scripts;
- define a software remote-desktop security model.

Remote access should therefore be treated as a separate post-installation
project.

---

## 20. Recovery from the Arch USB and Timeshift

### 20.1 If the system still reaches a TTY

For a broken package/configuration update:

```bash
sudo timeshift --list
```

Restore interactively:

```bash
sudo timeshift --restore
```

Or select a specific snapshot:

```bash
sudo timeshift --restore --snapshot "SNAPSHOT_NAME"
```

Read the proposed target mappings before confirming.

Reboot when Timeshift requests it.

### 20.2 Boot from the Arch USB

If Arch no longer boots:

1. Boot the Arch USB in UEFI mode.
2. Load the keyboard.
3. Connect to the network if required.
4. Identify the current partition names.

```bash
loadkeys es

lsblk -e7 -p \
    -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS,MODEL
```

Example only:

```bash
export ESP_PART=/dev/nvme0n1p1
export BOOT_PART=/dev/nvme0n1p5
export ROOT_PART=/dev/nvme0n1p6
```

### 20.3 Open LUKS

```bash
cryptsetup open "$ROOT_PART" cryptroot
```

### 20.4 Mount the root and subvolumes

```bash
mount -o subvol=@ /dev/mapper/cryptroot /mnt

mkdir -p \
    /mnt/home \
    /mnt/var/log \
    /mnt/var/cache/pacman/pkg \
    /mnt/boot/efi

mount -o subvol=@home \
    /dev/mapper/cryptroot \
    /mnt/home

mount -o subvol=@log \
    /dev/mapper/cryptroot \
    /mnt/var/log

mount -o subvol=@pkg \
    /dev/mapper/cryptroot \
    /mnt/var/cache/pacman/pkg

mount "$BOOT_PART" /mnt/boot
mount "$ESP_PART" /mnt/boot/efi
```

Check:

```bash
findmnt -R /mnt
```

### 20.5 Chroot

```bash
arch-chroot /mnt
```

From here you can:

```bash
pacman -Syu
mkinitcpio -P
```

repair package/configuration problems, or repair GRUB.

### 20.6 Repair GRUB from chroot

```bash
pacman -S --needed grub efibootmgr os-prober fuse3 ntfs-3g

grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --recheck

os-prober
grub-mkconfig -o /boot/grub/grub.cfg
```

Verify:

```bash
test -f /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi \
    && echo "Windows Boot Manager intact"
```

Exit:

```bash
exit
umount -R /mnt
cryptsetup close cryptroot
reboot
```

### 20.7 Offline Timeshift restore

Timeshift supports restoring from another Linux environment when the installed system cannot boot. The practical method is to boot a Linux live environment with Timeshift available, identify the Btrfs device/snapshots, and use Timeshift's restore workflow.

Do not manually delete/rename Btrfs root subvolumes unless you understand the exact snapshot layout.

---

## 21. Troubleshooting

### `lsblk` does not show the Windows-created unallocated space

This is normal: unallocated disk space is not a block device.

Use:

```bash
parted /dev/nvme0n1 unit GiB print free
```

### The editor or pager is missing

A minimal install may not contain a text editor or pager. `sudo -e` can also fail when its configured fallback editor is absent.

This guide installs `neovim` and `less` in `archinstall`, so system files are edited with `nvim`.

If needed:

```bash
sudo pacman -S --needed neovim less
```

Then use:

```bash
sudo nvim /etc/default/grub
```

### `less` shows `[END]`

The command is not stuck. Press:

```text
q
```

### GRUB does not show Windows

```bash
sudo os-prober
```

If Windows is found:

```bash
sudo nvim /etc/default/grub
```

Ensure:

```ini
GRUB_DISABLE_OS_PROBER=false
```

Then:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### `grub-mkconfig` says `/boot/grub/grub.cfg.new` does not exist

Verify mountpoints and reinstall GRUB as described in section 11.5. Do not merely create the directory and assume GRUB was installed correctly.

### Windows says the PIN is unavailable

Re-enroll Windows Hello PIN or use account-password sign-in. Do not clear the TPM merely because of this message.

### `Resume-BitLocker` reports key protectors are required

Inspect existing protectors and TPM state. Add only missing TPM/recovery protectors, save recovery material externally, then resume protection. See section 16.4.

### SDDM cold boot gives a black screen with cursor

Use `Ctrl+Alt+F3`, verify NVIDIA/Intel, then restart SDDM:

```bash
sudo systemctl restart sddm
```

If that fixes it, configure early graphics modules in `mkinitcpio.conf`:

```ini
MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

Then:

```bash
sudo mkinitcpio -P
sudo reboot
```

### `nvidia_drm` modeset already returns `Y`

Do not add redundant `modeset=1` fixes. Modern Arch NVIDIA packages enable it by default.

### Timeshift says Btrfs quotas are not enabled

This is informational. Timeshift works without quotas.

### Windows boots directly instead of GRUB

Windows/firmware may have changed boot order.

Use the firmware boot menu, then:

```bash
sudo efibootmgr -v
```

Do not delete Windows Boot Manager.

---

## 22. References

- Arch Linux installation guide: https://wiki.archlinux.org/title/Installation_guide
- Archinstall: https://wiki.archlinux.org/title/Archinstall
- Archinstall project: https://github.com/archlinux/archinstall
- Dual boot with Windows: https://wiki.archlinux.org/title/Dual_boot_with_Windows
- GRUB: https://wiki.archlinux.org/title/GRUB
- Btrfs: https://wiki.archlinux.org/title/Btrfs
- Timeshift: https://wiki.archlinux.org/title/Timeshift
- Timeshift upstream: https://github.com/linuxmint/timeshift
- Arch system maintenance: https://wiki.archlinux.org/title/System_maintenance
- NVIDIA: https://wiki.archlinux.org/title/NVIDIA
- SDDM: https://wiki.archlinux.org/title/SDDM
- mkinitcpio: https://wiki.archlinux.org/title/Mkinitcpio

---

## Final warning

Before pressing **Install** in `archinstall`, the Windows partitions must still be marked as existing and untouched.

The only newly formatted partitions are:

```text
new ext4 /boot
new Btrfs/LUKS Arch root
```

The following must never be formatted by this procedure:

```text
Windows ESP
Windows C:
Microsoft Reserved partition
Windows Recovery/OEM partitions
```
