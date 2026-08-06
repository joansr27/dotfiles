# Windows 11 + Arch Linux dual boot with `archinstall` and dotfiles restoration

> **Objective:** this guide explains how to install Arch Linux alongside an existing Windows 11 installation on the same internal SSD using the official `archinstall` TUI. The procedure preserves Windows, configures Btrfs and LUKS encryption, installs GRUB, restores all official and AUR packages declared by this repository, and deploys the configurations managed with GNU Stow.
>
> **Warning:** partitioning and formatting disks can destroy data. Read the entire guide before starting, create a verified backup, and do not continue if your computer's partition map does not match what is expected.

## Table of contents

1. [Final result](#1-final-result)
2. [Assumptions and limitations](#2-assumptions-and-limitations)
3. [Safety rules](#3-safety-rules)
4. [Recommended partition layout](#4-recommended-partition-layout)
5. [Prepare Windows](#5-prepare-windows)
6. [Create the Arch Linux installation USB](#6-create-the-arch-linux-installation-usb)
7. [Configure the UEFI firmware](#7-configure-the-uefi-firmware)
8. [Boot the Arch Linux live environment](#8-boot-the-arch-linux-live-environment)
9. [Install Arch Linux with `archinstall`](#9-install-arch-linux-with-archinstall)
10. [First boot and base-system validation](#10-first-boot-and-base-system-validation)
11. [Configure GRUB to display Windows](#11-configure-grub-to-display-windows)
12. [Restore the repository-managed system](#12-restore-the-repository-managed-system)
13. [Enable system services](#13-enable-system-services)
14. [Start and validate Hyprland](#14-start-and-validate-hyprland)
15. [Configure Timeshift and backups](#15-configure-timeshift-and-backups)
16. [Validate Windows and resume BitLocker](#16-validate-windows-and-resume-bitlocker)
17. [Final checklist](#17-final-checklist)
18. [Maintenance rules](#18-maintenance-rules)
19. [Recovery from the Arch USB](#19-recovery-from-the-arch-usb)
20. [Troubleshooting](#20-troubleshooting)
21. [Publish this guide in the repository](#21-publish-this-guide-in-the-repository)
22. [Official references](#22-official-references)

---

## 1. Final result

The procedure produces the following system:

- Windows 11 remains installed and bootable.
- Arch Linux and Windows share the existing Windows EFI System Partition, but that partition is **never formatted**.
- Arch Linux uses a separate, unencrypted `/boot` partition formatted as `ext4`.
- The Arch Linux root filesystem uses Btrfs inside a LUKS2 container.
- `archinstall` creates the default Btrfs subvolume layout.
- GRUB presents a boot menu for Arch Linux and Windows Boot Manager.
- Swap is implemented with zram, not with an on-disk swap partition.
- The initial Arch installation is minimal and does not install an alternative desktop environment.
- The repository installer installs all official and AUR packages defined by the selected profile.
- GNU Stow deploys the configurations managed by the repository.
- Hyprland, SDDM, Waybar, audio, networking, Bluetooth, and the rest of the environment are installed from the repository manifests.

The recommended layout is:

| Partition | Filesystem | Encryption | Mount point | Action |
|---|---|---:|---|---|
| Existing Windows ESP | FAT32 | No | `/boot/efi` | Reuse; do not format |
| Existing Microsoft Reserved partition | Microsoft reserved | No | None | Do not modify |
| Windows partition | NTFS | BitLocker may be active | Windows `C:` | Shrink only from Windows |
| Recovery partitions | OEM/NTFS | No | None | Do not modify |
| New Arch boot partition | ext4 | No | `/boot` | Create and format |
| New Arch root partition | Btrfs | LUKS2 | `/` | Create, encrypt, and format |

### Why a separate `/boot` is used

Windows installations usually create a small EFI System Partition. If that ESP is mounted directly at `/boot`, the Linux kernels and initramfs images are stored inside it. This repository installs both `linux` and `linux-lts`, so a small ESP may run out of space.

This guide uses:

- `/boot`: a new 2 GiB ext4 partition containing kernels, initramfs images, and GRUB files.
- `/boot/efi`: the existing Windows ESP containing Windows Boot Manager and the GRUB EFI executable.

This keeps large files outside the Windows ESP and avoids having to resize it.

---

## 2. Assumptions and limitations

This guide assumes that:

- Windows 11 is already installed.
- Windows uses UEFI and a GPT partition table.
- Arch Linux will be installed on the same internal SSD.
- Windows Disk Management can shrink the `C:` partition and leave unallocated space.
- The firmware can boot the official Arch USB in UEFI mode.
- Secure Boot will initially be disabled.
- Linux hibernation is not required.
- Windows Fast Startup and hibernation will remain disabled.
- An Internet connection is available during installation.
- The user has access to the dotfiles repository.

It does not cover:

- Legacy BIOS systems or MBR disks.
- Replacing or deleting Windows.
- RAID.
- LVM.
- Intel RST/VMD migrations.
- Linux hibernation.
- Secure Boot configuration with custom keys.
- Moving Windows to another disk.
- Recovery of an already damaged partition table.

`archinstall` changes frequently. The exact wording of some menus may differ between versions, but the settings and safety checks described here still apply.

---

## 3. Safety rules

Follow these rules throughout the process:

1. Create a backup before modifying partitions.
2. Store the BitLocker recovery key outside the computer.
3. Disconnect external SSDs, hard drives, SD cards, and other storage devices.
4. Keep the computer connected to AC power.
5. Use **Manual partitioning** in `archinstall`.
6. Do not select **Wipe all selected drives** or any equivalent option that uses the entire disk.
7. Do not format the Windows EFI System Partition.
8. Do not delete the Microsoft Reserved partition, recovery partitions, or OEM partitions.
9. Only the two new Arch partitions must be formatted.
10. Review the final `archinstall` preview line by line before installing.
11. If anything is unclear, exit the installer before confirming. Reopening `archinstall` is safe; confirming an incorrect layout is not.

### Disconnect unrelated storage

Before starting, disconnect:

- External SSDs.
- External hard drives.
- SD cards.
- Additional USB flash drives.
- Any USB storage other than the Arch installation medium.

This substantially reduces the risk of selecting the wrong disk.

---

## 4. Recommended partition layout

### Recommended sizes

- Arch `/boot`: **2 GiB**.
- Encrypted Btrfs root: all remaining unallocated space.
- Practical minimum root size: approximately **80 GiB**.
- Comfortable workstation space: **150 GiB or more**.

No swap partition is created because zram will be used.

### Example layout

The partition numbers are only examples:

```text
/dev/nvme0n1
├─/dev/nvme0n1p1   FAT32   EFI System Partition       Windows ESP
├─/dev/nvme0n1p2           Microsoft Reserved         do not modify
├─/dev/nvme0n1p3   NTFS    Windows                    do not modify
├─/dev/nvme0n1p4   NTFS    Windows Recovery           do not modify
├─/dev/nvme0n1p5   ext4    ARCH_BOOT                  new, /boot
└─/dev/nvme0n1p6   crypto  Arch LUKS container        new
  └─cryptroot      Btrfs   Arch root                  /
```

Do not copy names such as `/dev/nvme0n1p5` without first checking the actual map with `lsblk`.

### Btrfs subvolumes

When `archinstall` asks whether it should use the default Btrfs subvolume layout, select it. It normally includes:

```text
@           /
@home       /home
@pkg        /var/cache/pacman/pkg
@log        /var/log
@snapshots  /.snapshots
```

This layout separates the root filesystem, personal data, package cache, logs, and snapshots.

---
## 5. Prepare Windows

Complete this entire section before booting the Arch USB.

### 5.1 Create a backup

Copy important data to storage that will not be partitioned. A snapshot stored on the same internal SSD does not protect against partitioning mistakes or physical SSD failure.

Protect at least:

- Personal documents.
- Repositories with unpushed changes.
- Browser recovery information.
- Password database backups.
- SSH and GPG keys.
- Application licenses.
- BitLocker recovery keys.

### 5.2 Update Windows and the firmware

Before creating the dual boot:

1. Install all pending Windows updates.
2. Install BIOS or firmware updates provided by the manufacturer.
3. Restart until no update requests another restart.
4. Confirm that Windows boots normally.

It is preferable to update the firmware before installing GRUB and changing the boot order.

### 5.3 Check UEFI and GPT

Press `Win + R` and run:

```text
msinfo32
```

Check:

```text
BIOS Mode: UEFI
```

Then open PowerShell as administrator:

```powershell
Get-Disk | Format-Table Number,FriendlyName,PartitionStyle,Size
```

The system disk must report:

```text
PartitionStyle: GPT
```

Stop the procedure if Windows uses Legacy BIOS or MBR.

### 5.4 Save the BitLocker recovery key

Open PowerShell as administrator:

```powershell
Get-BitLockerVolume
manage-bde -status C:
manage-bde -protectors -get C:
```

If BitLocker or Device Encryption is active, store the key in an external location, for example:

- A password manager.
- A printed copy.
- A trusted Microsoft account.
- An encrypted file on another device.

Do not continue without a recoverable copy. Changes to Secure Boot, firmware, or the bootloader may cause Windows to request this key.

### 5.5 Disable hibernation and Fast Startup

Open PowerShell or Command Prompt as administrator:

```powershell
powercfg.exe /hibernate off
```

The command disables hibernation and removes the hibernation file. Fast Startup depends on this mechanism and is also disabled.

It can be checked graphically under:

```text
Control Panel
→ Hardware and Sound
→ Power Options
→ Choose what the power buttons do
→ Change settings that are currently unavailable
```

The Fast Startup option must be unchecked or unavailable.

### 5.6 Check the Windows filesystem

In PowerShell as administrator:

```powershell
chkdsk C: /scan
```

Resolve any errors before shrinking the partition.

### 5.7 Shrink the Windows partition

Press `Win + R` and run:

```text
diskmgmt.msc
```

In Disk Management:

1. Carefully identify the internal SSD.
2. Right-click the main `C:` partition.
3. Select **Shrink Volume**.
4. Enter the amount of space to remove from Windows.
5. Confirm the operation.
6. Leave the new region as **Unallocated**.

Do not create a new NTFS volume in that space. `archinstall` will create the Linux partitions later.

Do not modify:

- The EFI System Partition.
- The Microsoft Reserved partition.
- Recovery partitions.
- OEM partitions.

After shrinking `C:`, restart Windows and confirm that it still works correctly.

### 5.8 Suspend BitLocker

After verifying that Windows boots with the new size, open PowerShell as administrator:

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
```

Check the status:

```powershell
Get-BitLockerVolume -MountPoint "C:"
```

`RebootCount 0` keeps protection suspended until it is resumed manually. The data remains encrypted; TPM-based boot validation is temporarily suspended.

### 5.9 Shut Windows down completely

Run:

```powershell
shutdown /s /f /t 0
```

Do not use Restart. The computer must shut down completely.

---

## 6. Create the Arch Linux installation USB

Use the current ISO from the official Arch Linux website. A 2 GiB flash drive is sufficient, although 4 GiB or more is recommended.

All contents of the flash drive will be erased.

### 6.1 Create it from Linux

Download the ISO and its signature file into the same directory.

Verify the signature:

```bash
gpg --keyserver-options auto-key-retrieve \
    --verify archlinux-*.iso.sig archlinux-*.iso
```

The signature must be valid. A warning saying that the key is not personally certified does not mean that the signature is invalid.

Identify the flash drive:

```bash
lsblk -p -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL
ls -l /dev/disk/by-id/usb-*
```

Using the persistent `/dev/disk/by-id/` path is preferable. Example:

```text
/dev/disk/by-id/usb-SanDisk_Ultra_EXAMPLE-0:0
```

Unmount its partitions:

```bash
sudo umount /dev/disk/by-id/usb-SanDisk_Ultra_EXAMPLE-0:0-part* 2>/dev/null || true
```

Write the ISO to the **entire device**, not to a numbered partition:

```bash
sudo dd \
    if="$HOME/Downloads/archlinux-YYYY.MM.DD-x86_64.iso" \
    of="/dev/disk/by-id/usb-SanDisk_Ultra_EXAMPLE-0:0" \
    bs=4M \
    status=progress \
    oflag=direct \
    conv=fsync
```

Then run:

```bash
sync
```

Replace the example paths with the real ones. Selecting the internal SSD as `of=` would destroy it.

### 6.2 Create it from Windows

Rufus can be used:

1. Download the official Arch ISO.
2. Open Rufus.
3. Select the correct flash drive.
4. Select the ISO.
5. Start writing it.
6. If Rufus asks between ISO mode and DD mode, select **DD mode**.

Double-check that the selected device is not the internal SSD.

---

## 7. Configure the UEFI firmware

Open the firmware settings. The key depends on the manufacturer and is commonly `F2`, `F10`, `F12`, `Delete`, or `Esc`.

Configure:

- Boot mode: **UEFI**.
- Legacy Boot or CSM: **disabled**.
- Secure Boot: **disabled initially**.
- USB boot: enabled.

Do not:

- Clear the TPM keys.
- Reinitialize the TPM.
- Manually delete UEFI boot entries.
- Change SATA, AHCI, RAID, RST, or VMD settings without understanding the consequences.

If the live environment does not detect the internal SSD, stop and investigate the storage controller. Blindly changing from RST/RAID to AHCI may prevent Windows from booting.

In the temporary boot menu, choose the flash-drive entry that begins with `UEFI:`.

---

## 8. Boot the Arch Linux live environment

### 8.1 Configure the keyboard

For a Spanish keyboard:

```bash
loadkeys es
```

### 8.2 Confirm that the system booted in UEFI mode

```bash
ls /sys/firmware/efi/efivars
```

Many files must be displayed. If the directory does not exist, restart and select the correct UEFI entry for the flash drive.

### 8.3 Connect to the Internet

With Ethernet, checking the connection is normally sufficient:

```bash
ping -c 3 archlinux.org
```

For Wi-Fi:

```bash
iwctl
```

Inside `iwctl`:

```text
device list
station DEVICE scan
station DEVICE get-networks
station DEVICE connect NETWORK_NAME
exit
```

Replace `DEVICE` with the interface shown by `device list`.

Verify:

```bash
ping -c 3 archlinux.org
```

### 8.4 Synchronize the time

```bash
timedatectl set-ntp true
timedatectl status
```

### 8.5 Inspect the disk before opening `archinstall`

```bash
lsblk -e7 -p \
    -o NAME,SIZE,TYPE,FSTYPE,FSVER,LABEL,PARTLABEL,PARTTYPE,MOUNTPOINTS,MODEL
```

Also run:

```bash
fdisk -l
```

Identify:

- The internal SSD.
- The existing FAT32 ESP.
- The Windows NTFS partition.
- The recovery partitions.
- The unallocated space created from Windows.

Write down the actual identifiers:

```text
Internal disk:         __________________________
Windows ESP:           __________________________
Windows partition:     __________________________
Unallocated space:     __________________________
```

Do not continue if the expected free space does not appear.

### 8.6 Start `archinstall`

The ISO already includes the installer:

```bash
archinstall
```

If the included version has a known issue fixed in a later release, it can be updated first:

```bash
pacman -Sy archinstall
archinstall
```

---
## 9. Install Arch Linux with `archinstall`

`archinstall` provides a full-screen terminal interface. Use the keys shown on screen, normally the arrow keys, Enter, Space, and Escape.

### 9.1 Language, keyboard, and time zone

Configure:

- Installer language.
- Correct keyboard layout.
- System language and UTF-8 locale.
- Local time zone.
- Automatic time synchronization.

### 9.2 Mirrors

Select a nearby region or allow the installer to choose suitable mirrors.

### 9.3 Disk configuration

Open:

```text
Disk configuration
→ Manual partitioning
```

Do not use an automatic layout that occupies the entire disk.

Select the internal SSD that contains Windows. The editor must display the existing partitions and the free space.

#### 9.3.1 Create the `/boot` partition

Select the unallocated region and create a new partition:

- Size: **2 GiB**.
- Filesystem: `ext4`.
- Mount point: `/boot`.
- Format: **yes**.
- Encryption: **no**.

If it asks for start and end positions, use the beginning of the free space and create a 2 GiB partition.

#### 9.3.2 Create the Btrfs root

Use the remaining unallocated space for a second partition:

- Size: all remaining space.
- Filesystem: `btrfs`.
- Mount point: `/`.
- Format: **yes**.

When prompted about Btrfs:

- Select the default subvolume layout.
- Enable compression if the option is available.

Do not create a swap partition.

#### 9.3.3 Reuse the Windows ESP

Select the FAT32 partition that already contains Windows Boot Manager and change only its mount configuration:

- Mount point: `/boot/efi`.
- Format: **no**.
- Preserve existing filesystem: **yes**.
- Preserve existing data: **yes**.
- Keep the existing Boot/ESP flag.

The ESP usually contains:

```text
EFI/Microsoft/Boot/bootmgfw.efi
```

Do not format this partition under any circumstances.

#### 9.3.4 Do not modify the other Windows partitions

For the Windows NTFS partition, Microsoft Reserved partition, and recovery partitions:

- Do not assign a mount point during installation.
- Do not enable formatting.
- Do not delete them.
- Do not resize them from `archinstall`.

#### 9.3.5 Confirm the layout

Before leaving the editor, it must show exactly:

- An existing FAT32 ESP mounted at `/boot/efi`, without formatting.
- A new 2 GiB ext4 partition mounted at `/boot`, which will be formatted.
- A new Btrfs partition mounted at `/`, which will be formatted.
- No changes to Windows, MSR, or recovery partitions.

Select **Confirm and exit** only when this is correct.

> **Compatibility check:** GRUB supports an ext4 partition at `/boot` and the ESP at `/boot/efi`. If a particular `archinstall` version rejects this layout, do not replace `/boot` with the small Windows ESP. Exit without installing, update `archinstall`, or use a manual installation. Do not risk the Windows ESP.

### 9.4 Disk encryption

Open the encryption menu:

- Type: LUKS.
- Select only the new Btrfs root partition.
- Do not encrypt `/boot`.
- Do not encrypt the ESP.
- Enter and confirm a strong passphrase.

The LUKS passphrase will be requested every time Arch boots. If all valid passphrases are lost, the encrypted data cannot be recovered.

### 9.5 Bootloader

Select:

```text
GRUB
```

Recommended settings:

- Unified Kernel Images: disabled for this layout.
- Installation to removable path: disabled unless the firmware requires it.
- EFI destination: the existing ESP mounted at `/boot/efi`.

GRUB will add its own directory inside the ESP without replacing Windows Boot Manager.

### 9.6 Swap

Select:

```text
Swap on zram
```

This guide does not configure Linux hibernation.

### 9.7 Hostname

Use a simple hostname containing lowercase letters, numbers, and hyphens. Example:

```text
arch-workstation
```

### 9.8 User

Create at least one normal user:

- With administrative permissions or membership in `wheel`.
- With access to `sudo`.
- With a strong password.

The repository installer must be run as this normal user, not as root.

The root password is optional. It may be left empty to disable direct root login and administer the system through `sudo`.

### 9.9 Installation profile

Select a **minimal** installation.

Do not select a desktop environment. The repository will install Hyprland, SDDM, Waybar, portals, audio, and applications. Installing another desktop here would increase duplication and conflicts.

### 9.10 Audio

It may be left unconfigured because the repository installs PipeWire and WirePlumber. Selecting PipeWire in `archinstall` is also valid, but not required.

### 9.11 Kernels

Select:

- `linux`
- `linux-lts`

The regular kernel will be the primary one, while LTS will provide an alternative in case of regressions.

### 9.12 Network

Select:

```text
NetworkManager
```

The live environment's network configuration may be copied, or the connection can be restored later with `nmcli`.

### 9.13 Additional repositories

Enable:

```text
multilib
```

The repository profiles include `lib32-*` packages required for gaming, Vulkan, and compatibility. The installer stops if these packages are needed and `multilib` is not enabled.

If the current `archinstall` version does not display this option, it will be enabled manually after the first boot.

### 9.14 Additional packages

Add:

```text
git os-prober fuse3 ntfs-3g
```

Functions:

- `git`: clone the repository.
- `os-prober`: detect Windows for GRUB.
- `fuse3`: allow GRUB tools to inspect other filesystems.
- `ntfs-3g`: improve NTFS detection and conservatively handle hibernated volumes.

GRUB is installed automatically because it was selected as the bootloader.

### 9.15 Review the final preview

Before selecting Install, confirm:

- The correct internal SSD is selected.
- Manual partitioning is being used.
- The Windows NTFS partition will not be formatted.
- The recovery partitions will not be formatted.
- The existing ESP is mounted at `/boot/efi` and will not be formatted.
- The new 2 GiB ext4 partition is mounted at `/boot` and will be formatted.
- The new Btrfs partition is mounted at `/` and will be formatted.
- LUKS is applied only to the Btrfs root.
- GRUB is selected.
- `linux` and `linux-lts` will be installed.
- NetworkManager is selected.
- A user with sudo access exists.
- `multilib` is enabled or will be enabled immediately afterward.

Only then start the installation.

### 9.16 Finish

Wait until `archinstall` reports that the installation completed successfully.

The logs are stored at:

```text
/var/log/archinstall/install.log
```

When it offers to enter the chroot after installation, this can normally be declined because the following steps are documented below.

Restart:

```bash
reboot
```

Remove the flash drive when the restart begins.

---

## 10. First boot and base-system validation

The first boot should display:

1. The GRUB menu.
2. The LUKS passphrase prompt.
3. A login console.

Log in with the normal user created in `archinstall`.

### 10.1 Verify mounts and encryption

```bash
lsblk -f
findmnt /
findmnt /boot
findmnt /boot/efi
```

The following must be true:

- `/` is Btrfs on a LUKS/device-mapper device.
- `/boot` is the new ext4 partition.
- `/boot/efi` is the existing FAT32 ESP.

Check the subvolumes:

```bash
sudo btrfs subvolume list /
```

`@`, `@home`, `@pkg`, `@log`, and `@snapshots` should appear, or the equivalent default layout for the installed version.

### 10.2 Verify both kernels

```bash
ls -lh /boot
pacman -Q linux linux-lts
uname -r
```

Restart once and test LTS from GRUB's advanced options:

```bash
sudo reboot
```

After booting LTS:

```bash
uname -r
```

The version should contain `lts`.

### 10.3 Connect to the network

```bash
nmcli device status
```

For Wi-Fi:

```bash
nmcli device wifi list
nmcli device wifi connect "NETWORK_NAME" password "NETWORK_PASSWORD"
```

Verify:

```bash
ping -c 3 archlinux.org
```

### 10.4 Update the base system

```bash
sudo pacman -Syu
```

### 10.5 Verify or enable `multilib`

```bash
pacman-conf --repo-list | grep -x multilib
```

If it returns `multilib`, continue.

If not, edit:

```bash
sudoedit /etc/pacman.conf
```

Uncomment:

```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Update:

```bash
sudo pacman -Syu
```

Check again:

```bash
pacman-conf --repo-list | grep -x multilib
```

---

## 11. Configure GRUB to display Windows

`archinstall` may install GRUB correctly without adding Windows to the menu. Detection is configured explicitly after the first boot.

### 11.1 Check Windows Boot Manager

```bash
sudo test -f /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi \
    && echo "Windows Boot Manager found" \
    || echo "Windows Boot Manager not found"
```

If it does not appear, check that the correct ESP is mounted:

```bash
findmnt /boot/efi
lsblk -f
```

Do not format anything during this check.

### 11.2 Install dependencies

```bash
sudo pacman -S --needed os-prober fuse3 ntfs-3g
```

### 11.3 Enable `os-prober`

```bash
sudoedit /etc/default/grub
```

Add or modify:

```ini
GRUB_DISABLE_OS_PROBER=false
GRUB_TIMEOUT=5
```

### 11.4 Detect Windows and regenerate the menu

```bash
sudo os-prober
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Check:

```bash
grep -i windows /boot/grub/grub.cfg
```

Restart and test both Arch and Windows:

```bash
sudo reboot
```

If Windows does not appear, see [GRUB does not display Windows](#grub-does-not-display-windows).

---

## 12. Restore the repository-managed system

The repository is the source of truth for selected packages and configurations. It is not a backup of personal documents, browser profiles, credentials, SSH keys, or application data.

### 12.1 Install Git

```bash
sudo pacman -S --needed git
```

### 12.2 Clone into the required path

The repository must reside at `~/dotfiles`:

```bash
git clone \
    https://github.com/joansr27/dotfiles.git \
    "$HOME/dotfiles"
```

Then:

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
```

The working tree must be clean.

### 12.3 Choose the machine profile

The current profiles include:

```text
amd-current
omen
```

Select the appropriate one. Example:

```bash
export PROFILE=omen
```

Or:

```bash
export PROFILE=amd-current
```

Check:

```bash
printf 'Selected profile: %s\n' "$PROFILE"
```

### 12.4 Resolve and validate manifests

```bash
cd "$HOME/dotfiles"

./scripts/resolve-packages.sh "$PROFILE" | less
./scripts/resolve-aur-packages.sh "$PROFILE" | less
./scripts/validate-packages.sh "$PROFILE"
```

The active manifests, not the historical inventories under `docs/`, determine what is installed.

### 12.5 Run the complete installer

Run it as the normal user:

```bash
cd "$HOME/dotfiles"
./install/install.sh "$PROFILE"
```

This is a single, complete migration step. The installer:

1. Verifies that the system is Arch Linux.
2. Resolves the official package profile.
3. Checks `multilib` if `lib32-*` packages are required.
4. Updates the system.
5. Installs all declared official packages.
6. Installs `yay` if it is not present.
7. Resolves and installs all AUR packages in the profile.
8. Selects the Hyprland machine profile.
9. Creates the standard personal directories.
10. Checks for GNU Stow conflicts.
11. Deploys all configurations with Stow.
12. Configures the default browser and PDF reader.

Do not run the entire script with `sudo`:

```text
Incorrect: sudo ./install/install.sh omen
Correct:   ./install/install.sh omen
```

The script itself requests `sudo` only when necessary.

### 12.6 AUR confirmations

The installer uses `yay` for the declared AUR packages. During the process:

- Carefully review package names.
- Inspect PKGBUILD changes when prompted.
- Do not build AUR packages as root.
- Stop if a source URL or build script is unexpected.

This guide installs the complete profile, including AUR packages, in the same installer run. It does not maintain a separate AUR phase.

### 12.7 Resolve Stow conflicts

On a new minimal installation, there should be few conflicts. If the installer stops during the Stow check, the packages may have been installed, but the configurations will not yet have been deployed.

Do not use `stow --adopt` without understanding its effects.

Example for backing up a Waybar conflict:

```bash
backup="$HOME/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/waybar" "$backup/waybar-copy" 2>/dev/null || true
mv "$HOME/.config/waybar" "$backup/waybar-original" 2>/dev/null || true
```

Repeat the check:

```bash
cd "$HOME/dotfiles"
./scripts/stow-preflight.sh
```

Then run again:

```bash
./install/install.sh "$PROFILE"
```

Pacman and `yay` use `--needed`, so already installed packages should not be rebuilt unnecessarily.

### 12.8 Validate the deployment

```bash
cd "$HOME/dotfiles"

./scripts/check-desktop-config.sh
./scripts/stow-preflight.sh
./scripts/validate-packages.sh "$PROFILE"
```

Inspect links:

```bash
find "$HOME/.config" \
    -xtype l \
    -lname '*dotfiles*' \
    -print
```

Check the selected machine profile:

```bash
ls -l "$HOME/.config/hypr/machine.conf"
readlink -f "$HOME/.config/hypr/machine.conf"
```

---
## 13. Enable system services

The repository installer does not enable services automatically. This keeps activation explicit and auditable.

### 13.1 Main services

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now firewalld
sudo systemctl enable --now cronie
sudo systemctl enable --now power-profiles-daemon
```

SDDM will be enabled after Hyprland has been validated.

Check for failures:

```bash
systemctl --failed
```

Inspect individual services when necessary:

```bash
systemctl status NetworkManager --no-pager
systemctl status bluetooth --no-pager
systemctl status firewalld --no-pager
systemctl status power-profiles-daemon --no-pager
```

Do not enable multiple competing power managers at the same time.

### 13.2 Tailscale

If the profile includes Tailscale and remote access is required:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

Complete the authentication requested by `tailscale up`.

### 13.3 Sunshine

Sunshine may be installed by the profile, but it must be configured and tested before being enabled permanently.

Start it manually as the desktop user:

```bash
systemctl --user start app-dev.lizardbyte.app.Sunshine
```

Check:

```bash
systemctl --user status app-dev.lizardbyte.app.Sunshine --no-pager
```

A self-signed certificate warning in Sunshine's local interface is expected until a trusted certificate is configured. Always confirm that the address belongs to the local machine.

---

## 14. Start and validate Hyprland

### 14.1 Check the configuration format

Recent Hyprland versions use the following by default:

```text
~/.config/hypr/hyprland.lua
```

Earlier versions of the repository may provide:

```text
~/.config/hypr/hyprland.conf
```

Check:

```bash
ls -l "$HOME/.config/hypr/hyprland."*
```

#### Case A: `hyprland.lua` exists

Test from a TTY:

```bash
Hyprland
```

#### Case B: only `hyprland.conf` exists

Explicitly start the old configuration:

```bash
Hyprland --config "$HOME/.config/hypr/hyprland.conf"
```

This route makes it possible to use the repository's current state while the configuration is migrated to Lua.

### 14.2 Create a compatibility session for SDDM

Complete this subsection only if `hyprland.conf` exists but `hyprland.lua` does not.

Create a launcher:

```bash
sudo tee /usr/local/bin/start-hyprland-dotfiles >/dev/null <<'SCRIPT'
#!/usr/bin/env sh
exec Hyprland --config "$HOME/.config/hypr/hyprland.conf"
SCRIPT
```

Set permissions:

```bash
sudo chmod 755 /usr/local/bin/start-hyprland-dotfiles
```

Create the SDDM session:

```bash
sudo tee /usr/share/wayland-sessions/hyprland-dotfiles.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Name=Hyprland Dotfiles
Comment=Hyprland with the repository-managed configuration
Exec=/usr/local/bin/start-hyprland-dotfiles
Type=Application
DesktopNames=Hyprland
DESKTOP
```

Verify:

```bash
cat /usr/share/wayland-sessions/hyprland-dotfiles.desktop
```

### 14.3 Test from a TTY before enabling SDDM

Use the appropriate command:

```bash
Hyprland
```

Or:

```bash
Hyprland --config "$HOME/.config/hypr/hyprland.conf"
```

Inside Hyprland, open a terminal and run:

```bash
hyprctl configerrors
hyprctl monitors all
```

Then:

```bash
cd "$HOME/dotfiles"
./scripts/check-desktop-config.sh
```

Check user services:

```bash
systemctl --user --failed
journalctl --user -b -p warning
```

Exit using the configured shortcut or:

```bash
hyprctl dispatch exit
```

### 14.4 Enable SDDM

Once Hyprland starts correctly from a TTY:

```bash
sudo systemctl enable sddm
sudo systemctl start sddm
```

At the login screen:

- Select the normal Hyprland session if `hyprland.lua` exists.
- Select **Hyprland Dotfiles** if `hyprland.conf` compatibility is being used.

### 14.5 Validate graphics

General checks:

```bash
lspci -k -d ::03xx
hyprctl monitors all
```

For NVIDIA profiles:

```bash
nvidia-smi
cat /sys/module/nvidia_drm/parameters/modeset
```

It should normally report:

```text
Y
```

Vulkan:

```bash
vulkaninfo --summary
```

OpenGL:

```bash
glxinfo -B
```

The commands will be available if the corresponding packages are part of the profile.

### 14.6 Adjust monitors

Connector names vary between computers. Obtain the actual names:

```bash
hyprctl monitors all
```

Modify only the selected machine profile under:

```text
~/.config/hypr/machines/
```

Do not add machine-specific rules to the common configuration.

Apply the changes:

```bash
hyprctl reload
hyprctl configerrors
```

---

## 15. Configure Timeshift and backups

Timeshift makes it possible to recover the system after updates or configuration mistakes. It is not a substitute for an external backup.

### 15.1 Check Btrfs

```bash
findmnt -no FSTYPE,OPTIONS /
sudo btrfs subvolume list /
```

The root filesystem must use Btrfs and the default layout created by `archinstall`.

### 15.2 Configure Timeshift

```bash
sudo timeshift-gtk
```

Recommended initial settings:

- Type: Btrfs.
- Device: the encrypted Arch Btrfs system.
- Root subvolume: `@`.
- Exclude `/home` from system snapshots unless the opposite is explicitly desired.
- Keep a moderate number of daily and weekly snapshots.

Create an initial snapshot:

```bash
sudo timeshift \
    --create \
    --comments "Initial working Arch and Hyprland installation" \
    --tags O
```

List snapshots:

```bash
sudo timeshift --list
```

### 15.3 Back up the LUKS header

Identify the encrypted physical partition:

```bash
lsblk -f
```

Store the header on an encrypted external disk, not on the same SSD:

```bash
sudo cryptsetup luksHeaderBackup \
    /dev/REPLACE_WITH_ARCH_ROOT_PARTITION \
    --header-backup-file /PATH/ON/EXTERNAL/DISK/arch-luks-header.img
```

The file is sensitive and must never be uploaded to Git.

### 15.4 Back up data not included in the repository

The repository does not contain:

- Personal documents.
- SSH private keys.
- GPG private keys.
- Browser profiles.
- Password databases.
- Application credentials.
- Tailscale authentication keys.
- Sunshine credentials.
- License material.

Use an encrypted external disk or another reliable backup system.

---

## 16. Validate Windows and resume BitLocker

Restart and select Windows Boot Manager from GRUB.

Windows may request the BitLocker recovery key once because of the changes to Secure Boot or the boot chain. Use the key saved before installation.

Check:

- Windows boots correctly.
- The files are present.
- `C:` has the expected reduced size.
- Windows Update works.
- Device Manager does not show unexpected problems.

Once both systems have booted correctly several times, open PowerShell as administrator:

```powershell
Resume-BitLocker -MountPoint "C:"
```

Verify:

```powershell
Get-BitLockerVolume -MountPoint "C:"
```

Keep hibernation and Fast Startup disabled.

---

## 17. Final checklist

### Storage and encryption

```bash
lsblk -f
findmnt /
findmnt /boot
findmnt /boot/efi
sudo btrfs subvolume list /
```

Confirm:

- The root filesystem is encrypted.
- The root filesystem uses Btrfs.
- `/boot` uses ext4.
- `/boot/efi` uses FAT32.
- The Windows partitions are intact.

### Boot

```bash
efibootmgr -v
sudo os-prober
grep -i windows /boot/grub/grub.cfg
```

Confirm:

- A GRUB UEFI entry exists.
- Windows Boot Manager is still present.
- GRUB contains an entry for Windows.
- Both the regular and LTS kernels boot.

### Repository and packages

```bash
cd "$HOME/dotfiles"

git status
./scripts/validate-packages.sh "$PROFILE"
./scripts/stow-preflight.sh
./scripts/check-desktop-config.sh
```

### Services

```bash
systemctl --failed
systemctl --user --failed
```

### Desktop

```bash
hyprctl configerrors
hyprctl monitors all
```

### Network and firewall

```bash
nmcli device status
firewall-cmd --state
```

### Audio

```bash
wpctl status
```

### Bluetooth

```bash
bluetoothctl show
```

### Zram

```bash
swapon --show
zramctl
```

### Snapshots

```bash
sudo timeshift --list
```

---
## 18. Maintenance rules

### Keep Fast Startup disabled

Windows may change power settings after some updates. Check periodically:

```powershell
powercfg /a
```

Do not mount a hibernated Windows volume read-write from Linux.

### Suspend BitLocker before firmware changes

Before updating the BIOS, TPM firmware, or configuring Secure Boot:

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
```

After validating Windows:

```powershell
Resume-BitLocker -MountPoint "C:"
```

### Update Arch as a complete transaction

```bash
sudo pacman -Syu
```

Do not perform partial upgrades on the installed system.

### Review AUR updates

```bash
yay -Syu
```

Review PKGBUILD and source changes before accepting updates.

### Maintain the manifests

When adding or removing packages, use the repository scripts and documented workflow. Do not rely only on terminal history.

### Regenerate GRUB after configuration changes

After modifying `/etc/default/grub`:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

To reinstall GRUB:

```bash
sudo grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --recheck

sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Keep the installation USB

The flash drive can also be used to:

- Repair GRUB.
- Open LUKS.
- Mount Btrfs subvolumes.
- Reinstall kernels.
- Correct configurations.
- Copy data to an external disk.

---

## 19. Recovery from the Arch USB

The devices shown are examples. Replace them with those obtained from `lsblk`.

### 19.1 Boot the live USB

Boot in UEFI mode, configure the keyboard, and inspect the disks:

```bash
loadkeys es

lsblk -e7 -p \
    -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS,MODEL
```

Define the actual partitions:

```bash
export ESP_PART=/dev/nvme0n1p1
export BOOT_PART=/dev/nvme0n1p5
export ROOT_PART=/dev/nvme0n1p6
```

These are examples. Verify every value.

### 19.2 Open LUKS

```bash
cryptsetup open "$ROOT_PART" cryptroot
```

### 19.3 Mount Btrfs

```bash
mount -o subvol=@ /dev/mapper/cryptroot /mnt

mkdir -p \
    /mnt/home \
    /mnt/var/cache/pacman/pkg \
    /mnt/var/log \
    /mnt/.snapshots \
    /mnt/boot/efi

mount -o subvol=@home \
    /dev/mapper/cryptroot \
    /mnt/home

mount -o subvol=@pkg \
    /dev/mapper/cryptroot \
    /mnt/var/cache/pacman/pkg

mount -o subvol=@log \
    /dev/mapper/cryptroot \
    /mnt/var/log

mount -o subvol=@snapshots \
    /dev/mapper/cryptroot \
    /mnt/.snapshots
```

Mount the boot partition and ESP:

```bash
mount "$BOOT_PART" /mnt/boot
mount "$ESP_PART" /mnt/boot/efi
```

Check:

```bash
findmnt -R /mnt
```

### 19.4 Enter the system

```bash
arch-chroot /mnt
```

### 19.5 Reinstall kernels and initramfs images

```bash
pacman -Syu linux linux-lts linux-firmware
mkinitcpio -P
```

### 19.6 Repair GRUB

```bash
pacman -S --needed grub efibootmgr os-prober fuse3 ntfs-3g

grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --recheck
```

Check Windows Boot Manager:

```bash
test -f /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi \
    && echo "Windows Boot Manager found"
```

Make sure `/etc/default/grub` contains:

```ini
GRUB_DISABLE_OS_PROBER=false
```

Then:

```bash
os-prober
grub-mkconfig -o /boot/grub/grub.cfg
```

Exit and unmount:

```bash
exit
umount -R /mnt
cryptsetup close cryptroot
reboot
```

### 19.7 Temporarily disable SDDM

If the system boots but SDDM displays a black screen, switch to a TTY with a combination such as `Ctrl + Alt + F3`, log in, and run:

```bash
sudo systemctl disable --now sddm
```

Test Hyprland manually:

```bash
Hyprland
```

Or:

```bash
Hyprland --config "$HOME/.config/hypr/hyprland.conf"
```

Re-enable SDDM only after obtaining a working session.

---

## 20. Troubleshooting

### The internal SSD does not appear

```bash
lsblk
lspci -nnk
```

Possible causes:

- Intel RST or VMD controller.
- Missing storage driver.
- Firmware hiding the device.
- An ISO that is too old.

Do not blindly change the storage mode. Windows may stop booting after an RST/AHCI change if it is not prepared beforehand.

### `archinstall` does not show unallocated space

Return to Windows Disk Management and check that the region is genuinely **Unallocated**, not a new NTFS volume.

If Windows cannot shrink it enough:

- Delete unnecessary files.
- Empty the Recycle Bin.
- Disable hibernation.
- Temporarily reduce restore points.
- Optimize the drive.
- Try shrinking it again.

Do not resize the Windows system partition from Linux without a specific recovery plan.

### `archinstall` proposes formatting the ESP

Cancel the change. Edit the ESP and set:

- `/boot/efi` as the mount point.
- Formatting disabled.
- Existing FAT32 preserved.

Do not continue until the preview clearly shows that it will not be formatted.

### GRUB does not display Windows

Check the ESP:

```bash
findmnt /boot/efi
ls /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi
```

Install dependencies:

```bash
sudo pacman -S --needed os-prober fuse3 ntfs-3g
```

Check that the following exists:

```ini
GRUB_DISABLE_OS_PROBER=false
```

Regenerate the configuration:

```bash
sudo os-prober
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

If it still fails, Windows may not have shut down completely. Boot Windows, verify that hibernation is disabled, and run:

```powershell
shutdown /s /f /t 0
```

Then try again from Arch.

### Windows boots directly and skips GRUB

```bash
efibootmgr -v
```

Temporarily select GRUB from the UEFI menu. Then put the GRUB entry first through the firmware or `efibootmgr`, carefully identifying the entry numbers.

A Windows or firmware update may change the boot order without deleting Arch.

### The LUKS passphrase does not work

Check the keyboard layout. The keymap during boot may differ from the one used when creating the passphrase.

It can be tested from the USB:

```bash
loadkeys es
cryptsetup open /dev/ARCH_ROOT_PARTITION testcrypt
cryptsetup close testcrypt
```

### The repository installer reports that `multilib` is disabled

```bash
sudoedit /etc/pacman.conf
```

Uncomment:

```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Then:

```bash
sudo pacman -Syu
cd "$HOME/dotfiles"
./install/install.sh "$PROFILE"
```

### The installer stops at Stow

Do not delete files blindly or use `stow --adopt` without reviewing its effects.

Back up or move the conflicting target and run again:

```bash
cd "$HOME/dotfiles"
./scripts/stow-preflight.sh
./install/install.sh "$PROFILE"
```

### SDDM returns to the login screen

Temporarily disable SDDM:

```bash
sudo systemctl disable --now sddm
```

Check the configurations:

```bash
ls -l "$HOME/.config/hypr/hyprland."*
```

Test:

```bash
Hyprland
```

Or:

```bash
Hyprland --config "$HOME/.config/hypr/hyprland.conf"
```

Review logs:

```bash
journalctl --user -b -p warning
journalctl -b -u sddm --no-pager
```

Use the compatibility session if the repository still uses `hyprland.conf`.

### The NVIDIA session is black or unstable

From a TTY:

```bash
nvidia-smi
lspci -k -d ::03xx
cat /sys/module/nvidia_drm/parameters/modeset
```

Validate the profile:

```bash
cd "$HOME/dotfiles"
./scripts/validate-packages.sh "$PROFILE"
```

Test the LTS kernel from GRUB. Keep machine-specific changes inside its profile and avoid copying obsolete NVIDIA variables from old guides.

### Windows requests the BitLocker recovery key

This may be normal after modifying Secure Boot or the boot chain. Use the previously saved key.

After validating the dual boot:

```powershell
Resume-BitLocker -MountPoint "C:"
```

---

## 21. Publish this guide in the repository

The recommended path is:

```text
docs/archinstall-windows-dual-boot.md
```

### 21.1 Copy the file into the repository

Assuming that the browser saved it under `~/Downloads`:

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only

git switch -c docs/archinstall-windows-dual-boot

mkdir -p docs
cp "$HOME/Downloads/archinstall-windows-dual-boot.md" \
   docs/archinstall-windows-dual-boot.md
```

Replace the source path if the file is located elsewhere.

### 21.2 Review before committing

```bash
git status --short
git diff --check
git diff -- docs/archinstall-windows-dual-boot.md
```

Check that it does not contain:

- Credentials.
- Recovery keys.
- Serial numbers.
- Private hostnames.
- Private IP addresses that should not be published.
- Unnecessary personal paths.

### 21.3 Create the commit

```bash
git add docs/archinstall-windows-dual-boot.md

git diff --cached --stat
git diff --cached

git commit -m "docs: add Arch and Windows dual-boot guide"
```

### 21.4 Push the branch

```bash
git push -u origin docs/archinstall-windows-dual-boot
```

### 21.5 Open a pull request

With GitHub CLI:

```bash
gh pr create \
    --base main \
    --head docs/archinstall-windows-dual-boot \
    --title "docs: add Arch and Windows dual-boot guide" \
    --body "Adds a complete archinstall-based procedure for preserving Windows, creating an encrypted Btrfs Arch installation, configuring GRUB, and restoring the repository-managed system."
```

The repository can also be opened on GitHub and **Compare & pull request** can be used for the pushed branch.

### 21.6 Add a link to the README

After reviewing the guide, it can be added to the README installation section:

```markdown
- [Windows 11 + Arch Linux dual boot with archinstall](docs/archinstall-windows-dual-boot.md)
```

Review the diff and create an additional commit or include it in the same documentation pull request.

---

## 22. Official references

- [Arch Linux downloads](https://archlinux.org/download/)
- [Official Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide)
- [ArchWiki: archinstall](https://wiki.archlinux.org/title/Archinstall)
- [Official archinstall repository and dual-boot FAQ](https://github.com/archlinux/archinstall)
- [archinstall guided installation documentation](https://archinstall.archlinux.page/installing/guided.html)
- [archinstall disk-configuration documentation](https://archinstall.archlinux.page/cli_parameters/config/disk_config.html)
- [ArchWiki: Dual boot with Windows](https://wiki.archlinux.org/title/Dual_boot_with_Windows)
- [ArchWiki: GRUB](https://wiki.archlinux.org/title/GRUB)
- [ArchWiki: Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [ArchWiki: recovery with chroot and Btrfs](https://wiki.archlinux.org/title/Chroot)
- [Microsoft: suspend BitLocker protection](https://learn.microsoft.com/es-es/troubleshoot/windows-client/windows-security/suspend-bitlocker-protection-non-microsoft-updates)
- [Microsoft: disable and enable hibernation](https://learn.microsoft.com/en-us/troubleshoot/windows-client/setup-upgrade-and-drivers/disable-and-re-enable-hibernation)
- [Hyprland: configuration start](https://wiki.hypr.land/Configuring/Start/)
- [Repository README](../README.md)

---

## Final warning

The two destructive operations in the procedure are:

1. Shrinking the Windows partition.
2. Formatting the two new Arch partitions.

The Windows ESP, Windows NTFS partition, Microsoft Reserved partition, and recovery partitions must not be formatted.

Before selecting **Install** in `archinstall`, review the entire partitioning preview one final time.
