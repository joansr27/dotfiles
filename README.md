# Arch Linux / Hyprland Dotfiles

A reproducible Arch Linux workstation configuration built around Hyprland,
GNU Stow, machine-specific hardware profiles, explicit package manifests,
validation scripts, Timeshift recovery, and an intentionally restricted
Tailscale + Sunshine remote-access workflow.

> [!IMPORTANT]
> Clone this repository at `~/dotfiles`. Several scripts and configuration
> files intentionally rely on that location.

> [!TIP]
> Planning to reproduce this workstation on a Windows machine? Read
> **[Windows 11 + Arch Linux dual boot with `archinstall`](archinstall-windows-dual-boot.md)**
> before installing packages or modifying the Windows disk. It documents the
> complete partitioning, LUKS, Btrfs, GRUB, BitLocker, SDDM, NVIDIA, Timeshift,
> and repository-restoration procedure.

---

## Table of contents

1. [Goals and design principles](#1-goals-and-design-principles)
2. [Repository layout](#2-repository-layout)
3. [Security and privacy model](#3-security-and-privacy-model)
4. [GNU Stow configuration deployment](#4-gnu-stow-configuration-deployment)
5. [Package manifest architecture](#5-package-manifest-architecture)
6. [Machine-specific Hyprland profiles](#6-machine-specific-hyprland-profiles)
7. [Default applications](#7-default-applications)
8. [Installing a new computer](#8-installing-a-new-computer)
9. [Migrating an existing Arch installation](#9-migrating-an-existing-arch-installation)
10. [Updating an existing configuration](#10-updating-an-existing-configuration)
11. [Installing and recording packages](#11-installing-and-recording-packages)
12. [Removing packages](#12-removing-packages)
13. [Adding application configuration to Stow](#13-adding-application-configuration-to-stow)
14. [Remote access: Tailscale + Sunshine + iPad](#14-remote-access-tailscale--sunshine--ipad)
15. [Idle locking and session security](#15-idle-locking-and-session-security)
16. [XDG user directories](#16-xdg-user-directories)
17. [Git workflow](#17-git-workflow)
18. [Timeshift snapshots and system recovery](#18-timeshift-snapshots-and-system-recovery)
19. [Diagnostics](#19-diagnostics)
20. [Maintenance checklist](#20-maintenance-checklist)

---

## 1. Goals and design principles

The repository aims to:

1. Reconstruct the workstation on a clean Arch Linux installation.
2. Keep selected configuration under version control.
3. Separate common configuration from hardware-specific configuration.
4. Keep official and AUR package manifests explicit.
5. Deploy configuration through GNU Stow rather than unmanaged links.
6. Detect Stow conflicts before changing the live desktop.
7. Validate packages before migration.
8. Keep machine-specific graphics/monitor rules isolated.
9. Keep risky service activation explicit.
10. Avoid storing secrets or private application state.
11. Provide predictable rollback paths with Git and Timeshift.
12. Keep remote access disabled when it is not required.

The repository is **not** a full home-directory backup.

---

## 2. Repository layout

```text
dotfiles/
├── archinstall-windows-dual-boot.md
├── configs/
│   ├── hypr/
│   ├── kitty/
│   ├── nvim/
│   ├── waybar/
│   ├── wofi/
│   └── xdg-user-dirs/
├── docs/
├── install/
│   └── install.sh
├── packages/
│   ├── common/
│   ├── features/
│   ├── hardware/
│   ├── profiles/
│   └── aur/
├── scripts/
│   ├── remote-on.sh
│   ├── remote-off.sh
│   └── ...
├── wallpapers/
├── .gitignore
└── README.md
```

### `configs/`

Each direct child is a Stow package. For example:

```text
configs/hypr/.config/hypr/hyprland.conf
```

is deployed into:

```text
~/.config/hypr/hyprland.conf
```

### `packages/`

Active source of truth for package selection.

### `install/`

Contains the high-level clean-install migration script.

### `scripts/`

Contains package resolvers, validators, Stow helpers, machine selection, and
remote-access controls.

### `docs/`

Supporting documentation and historical inventories.

---

## 3. Security and privacy model

Never commit:

```text
~/.ssh/
~/.gnupg/
private keys
password databases
API keys
Tailscale auth keys
Sunshine credentials
Wi-Fi passwords
browser profiles/cookies
recovery codes
BitLocker recovery keys
LUKS header backups
.env files
personal documents
shell history
```

Before a commit:

```bash
git status --short
git diff --check
git diff
git diff --cached
```

Search suspicious names:

```bash
git diff --cached --name-only |
    grep -Ei \
    'secret|token|credential|password|private|\.env|id_rsa|id_ed25519'
```

Search suspicious content:

```bash
git diff --cached |
    grep -Ei \
    'api[_-]?key|access[_-]?token|client[_-]?secret|password'
```

### AUR trust boundary

AUR PKGBUILDs execute build logic under the current user.

Before accepting unusual AUR changes:

```bash
yay -Si package-name
yay -G package-name
nvim package-name/PKGBUILD
```

Review source URLs, checksums, `prepare()`, `build()`, `package()`, and install
scripts. Never run `makepkg` as root and do not bypass integrity/signature
checks merely to force a build to succeed.

---

## 4. GNU Stow configuration deployment

Stow directory:

```text
~/dotfiles/configs
```

Target:

```text
$HOME
```

Preflight:

```bash
cd "$HOME/dotfiles"
./scripts/stow-preflight.sh
```

Simulate one package:

```bash
stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    waybar
```

Deploy/redeploy:

```bash
./scripts/stow-config.sh waybar
```

Unstow:

```bash
./scripts/unstow-config.sh waybar
```

If a target is not owned by Stow, back it up. Do not use `stow --adopt`
blindly.

---

## 5. Package manifest architecture

Official packages resolve from:

```text
packages/profiles/<profile>.txt
```

AUR packages resolve from:

```text
packages/aur/profiles/<profile>.txt
```

Profiles:

```text
amd-current
omen
```

Resolve and validate:

```bash
./scripts/resolve-packages.sh amd-current
./scripts/resolve-packages.sh omen

./scripts/resolve-aur-packages.sh amd-current
./scripts/resolve-aur-packages.sh omen

./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen
```

Historical inventories under `docs/` are not active manifests.

---

## 6. Machine-specific Hyprland profiles

Machine configuration is selected through:

```text
~/.config/hypr/machine.conf
```

Profiles live under:

```text
~/.config/hypr/machines/
```

Select:

```bash
cd "$HOME/dotfiles"
./scripts/select-machine.sh omen
```

or:

```bash
./scripts/select-machine.sh amd-current
```

Discover real monitor names/modes:

```bash
hyprctl monitors all
```

Apply:

```bash
hyprctl reload
hyprctl configerrors
```

Do not assume connector names are identical between machines.

---

## 7. Default applications

### Firefox

```bash
xdg-settings set default-web-browser firefox.desktop

for mime in \
    text/html \
    application/xhtml+xml \
    x-scheme-handler/http \
    x-scheme-handler/https
do
    xdg-mime default firefox.desktop "$mime"
done
```

Verify:

```bash
xdg-settings get default-web-browser
xdg-mime query default x-scheme-handler/https
```

### Okular

```bash
xdg-mime default org.kde.okular.desktop application/pdf
xdg-mime query default application/pdf
```

---

## 8. Installing a new computer

For Windows dual boot, follow
[`archinstall-windows-dual-boot.md`](archinstall-windows-dual-boot.md).

The minimum base system must have:

- Bootable Arch.
- Normal sudo-capable user.
- NetworkManager/network access.
- Multilib.
- `git`.
- An editor (`nvim` recommended).

Clone:

```bash
git clone \
    https://github.com/joansr27/dotfiles.git \
    "$HOME/dotfiles"

cd "$HOME/dotfiles"
git switch main
git pull --ff-only
```

Inspect:

```bash
./scripts/resolve-packages.sh omen
./scripts/resolve-aur-packages.sh omen
./scripts/validate-packages.sh omen
```

Install:

```bash
./install/install.sh omen
```

or:

```bash
./install/install.sh amd-current
```

The installer intentionally does not enable all services automatically.

Core services:

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now firewalld
sudo systemctl enable sddm
```

Remote access is configured later, after the local desktop works.

---

## 9. Migrating an existing Arch installation

Back up existing configuration:

```bash
backup="$HOME/dotfiles-backup/existing-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/hypr" "$backup/hypr" 2>/dev/null || true
cp -aL "$HOME/.config/waybar" "$backup/waybar" 2>/dev/null || true
cp -aL "$HOME/.config/kitty" "$backup/kitty" 2>/dev/null || true
cp -aL "$HOME/.config/nvim" "$backup/nvim" 2>/dev/null || true
```

Migrate Stow packages deliberately:

```bash
./scripts/stow-preflight.sh
./scripts/stow-config.sh waybar
```

For Hyprland:

```bash
test -r "$HOME/.config/hypr/hyprland.conf"
hyprctl reload
hyprctl configerrors
```

---

## 10. Updating an existing configuration

Start clean:

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
```

For a substantial change:

```bash
git switch -c feature/descriptive-change
```

Edit Stow-managed files directly through either path:

```bash
nvim "$HOME/.config/waybar/config.jsonc"
```

or:

```bash
nvim \
    "$HOME/dotfiles/configs/waybar/.config/waybar/config.jsonc"
```

Test:

```bash
hyprctl reload
hyprctl configerrors
./scripts/check-desktop-config.sh
```

Review:

```bash
git status --short
git diff --check
git diff
```

Commit only intended files.

---

## 11. Installing and recording packages

Prefer:

```bash
./scripts/add-package.sh
```

Examples:

```bash
./scripts/add-package.sh \
    --source official \
    --package firefox \
    --manifest common/07-applications.txt
```

AUR:

```bash
./scripts/add-package.sh \
    --source aur \
    --package package-name \
    --manifest common.txt
```

Validate both profiles after manifest changes:

```bash
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen
```

Never record the same package in official and AUR manifests.

---

## 12. Removing packages

Create a branch for significant package-set changes:

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git switch -c packages/remove-package-name
```

Remove from the manifest, then uninstall only if appropriate:

```bash
sudo pacman -Rns package-name
```

Validate:

```bash
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen
```

---

## 13. Adding application configuration to Stow

Example for `~/.config/example`:

```bash
backup="$HOME/dotfiles-backup/example-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/example" "$backup/example-copy"

mkdir -p "$HOME/dotfiles/configs/example/.config"
cp -a \
    "$HOME/.config/example" \
    "$HOME/dotfiles/configs/example/.config/example"

mv "$HOME/.config/example" "$backup/example-original"
```

Simulate:

```bash
stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    example
```

Deploy:

```bash
./scripts/stow-config.sh example
```

---

## 14. Remote access: Tailscale + Sunshine + iPad

Remote access is intentionally **off by default** and should be configured only
after Hyprland, graphics, audio, SDDM, and the local input stack are stable.

### Architecture

```text
iPad
  ├─ Tailscale iPadOS VPN
  └─ Moonlight
         │
         │ encrypted Tailscale/WireGuard path
         ▼
Arch workstation
  ├─ tailscaled
  └─ Sunshine
```

No Sunshine router port forwarding is required.

### One-time host setup

Authenticate Tailscale once:

```bash
sudo systemctl start tailscaled
sudo tailscale up
tailscale status
tailscale ip -4
```

Configure Sunshine locally by starting it:

```bash
systemctl --user start app-dev.lizardbyte.app.Sunshine
```

Open on the workstation:

```text
https://localhost:47990
```

A self-signed certificate warning is expected for the verified local Sunshine
URL. Do not treat certificate warnings on unrelated sites as safe.

Create a strong Sunshine username/password.

Recommended Sunshine security:

```text
UPnP: disabled
Web UI: localhost/pc only
No public external IP configuration
No router forwarding
```

If desired and supported by the clients, require Sunshine's own stream
encryption as defense in depth; Tailscale already encrypts the network path.

### Tailscale admin console

Enable **Device approval** and approve only known devices.

For a strict streaming-only policy, use Tailscale **grants** to allow only the
selected iPad Tailscale IP to reach the Sunshine host ports.

Example:

```jsonc
{
  "hosts": {
    "stream-host": "100.HOST.IP.ADDRESS",
    "ipad-client": "100.IPAD.IP.ADDRESS"
  },

  "grants": [
    {
      "src": ["ipad-client"],
      "dst": ["stream-host"],
      "ip": [
        "tcp:47984",
        "tcp:47989",
        "tcp:48010",
        "udp:47998",
        "udp:47999",
        "udp:48000",
        "udp:48002"
      ]
    }
  ]
}
```

Do not copy real Tailscale addresses into this public repository.

### iPad one-time setup

Install:

- Tailscale.
- Moonlight Game Streaming.

Open Tailscale and allow iPadOS to add the VPN configuration.

Sign in to the same tailnet and approve the iPad from the Tailscale admin
console if device approval is enabled.

### Pair Moonlight

Start host remote access:

```bash
cd "$HOME/dotfiles"
./scripts/remote-on.sh
```

On iPad:

1. Enable Tailscale.
2. Open Moonlight.
3. Add the Arch workstation using its Tailscale `100.x.y.z` IP or MagicDNS
   name if it is not discovered automatically.
4. Moonlight presents a PIN.
5. On the workstation, open the local Sunshine Web UI.
6. Enter the PIN on Sunshine's PIN page.
7. Return to Moonlight and start the desired application/desktop.

### Daily workflow

#### Turn remote access on

From Hyprland:

```bash
cd "$HOME/dotfiles"
./scripts/remote-on.sh
```

Current implementation:

```bash
sudo systemctl start tailscaled
systemctl --user start app-dev.lizardbyte.app.Sunshine
```

Verify:

```bash
tailscale status
systemctl --user is-active app-dev.lizardbyte.app.Sunshine
```

#### Connect from iPad

1. Open Tailscale.
2. Confirm the VPN is connected.
3. Open Moonlight.
4. Select the workstation.
5. Start the stream.

#### Turn remote access off

After the session:

```bash
cd "$HOME/dotfiles"
./scripts/remote-off.sh
```

Current implementation stops Sunshine and then `tailscaled`.

Optionally disconnect Tailscale on the iPad.

> If the Tailscale/Sunshine stream is your only control path, `remote-off.sh`
> will intentionally terminate that connection.

### Security checks

Do not enable Sunshine UPnP.

Do not forward Sunshine ports on the router.

Do not commit:

- Tailscale auth keys.
- Real private tailnet policy data that should not be public.
- Sunshine credentials.
- Sunshine private keys/certificates.

---

## 15. Idle locking and session security

Hypridle is started by Hyprland.

Verify:

```bash
pacman -Q hypridle
command -v hypridle
test -r "$HOME/.config/hypr/hypridle.conf"
pgrep -a hypridle
```

Test locking:

```bash
loginctl lock-session
```

Do not run duplicate Hypridle instances through both `exec-once` and a user
service unless the startup model is deliberately changed.

---

## 16. XDG user directories

Managed by the `xdg-user-dirs` Stow package.

Inspect:

```bash
xdg-user-dir DESKTOP
xdg-user-dir DOWNLOAD
xdg-user-dir DOCUMENTS
xdg-user-dir PICTURES
```

Do not run `xdg-user-dirs-update` without checking whether it will rewrite
Stow-managed files.

---

## 17. Git workflow

Update `main`:

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
```

Small, low-risk, tested changes may be committed directly to `main`.

Use a branch for changes involving:

- Package manifests.
- Install scripts.
- Graphics.
- Boot.
- Services.
- Security.
- Remote access.
- Several machines/files.

Example:

```bash
git switch -c fix/sddm-graphics-startup
```

Review:

```bash
git status --short
git diff --check
git diff --stat
git diff
```

Stage selectively:

```bash
git add path/to/file
```

Inspect:

```bash
git diff --cached --check
git diff --cached --stat
git diff --cached
```

Commit/push:

```bash
git commit -m "fix: describe the change"
git push -u origin HEAD
```

---

## 18. Timeshift snapshots and system recovery

Timeshift is the system rollback layer for this workstation.

It protects the Linux system state. It does **not** replace backups of personal
files and it does not protect against physical SSD failure.

### 18.1 Review Timeshift

List snapshots:

```bash
sudo timeshift --list
```

Open the GUI:

```bash
sudo timeshift-gtk
```

For this repository's Btrfs layout, use Btrfs mode.

A message such as:

```text
btrfs: Quotas are not enabled
```

is informational; Timeshift does not require qgroups to create normal Btrfs
snapshots.

### 18.2 Create a snapshot

Before a risky package/configuration change:

```bash
sudo timeshift \
    --create \
    --comments "Before desktop configuration change"
```

Verify:

```bash
sudo timeshift --list
```

Recommended checkpoints include:

- Fresh working Arch + Hyprland installation.
- Before kernel/NVIDIA updates.
- Before SDDM/display-manager changes.
- Before large package removals.
- Before risky system configuration edits.

### 18.3 Review what a snapshot is for

Timeshift is designed primarily for system files/settings. Do not assume that
documents in `$HOME` are your backup just because a Timeshift snapshot exists.

Keep personal backups separately.

### 18.4 Restore while Arch still boots

List:

```bash
sudo timeshift --list
```

Interactive restore:

```bash
sudo timeshift --restore
```

Specific snapshot:

```bash
sudo timeshift --restore --snapshot "SNAPSHOT_NAME"
```

Read the source/target mappings before accepting the restore.

Reboot when requested.

### 18.5 If the graphical desktop is broken but TTY works

Use:

```text
Ctrl + Alt + F3
```

Log in and restore from the TTY:

```bash
sudo timeshift --list
sudo timeshift --restore
```

This is useful after a broken desktop, graphics, or configuration update.

### 18.6 If Arch no longer boots

Boot a Linux live environment in UEFI mode.

For this encrypted Btrfs installation:

1. Identify the disk with `lsblk`.
2. Open the LUKS partition.
3. Mount the Btrfs root and boot partitions if manual repair is required.
4. Use a live environment with Timeshift available for an offline Timeshift
   restore, or `arch-chroot` for manual repair.

The complete disk/chroot procedure is documented in
[`archinstall-windows-dual-boot.md`](archinstall-windows-dual-boot.md).

### 18.7 Git rollback versus Timeshift rollback

Use Git when only repository-managed configuration is wrong:

```bash
git restore path/to/file
git revert COMMIT_SHA
```

Use Timeshift when the **installed system state** is broken—for example a
kernel, driver, package, or system-wide configuration change.

---

## 19. Diagnostics

Repository:

```bash
cd "$HOME/dotfiles"

./scripts/check-desktop-config.sh
./scripts/stow-preflight.sh
./scripts/validate-packages.sh omen
```

Hyprland:

```bash
hyprctl reload
hyprctl configerrors
hyprctl monitors all
```

Processes:

```bash
pgrep -a waybar
pgrep -a hyprpaper
pgrep -a hypridle
```

System services:

```bash
systemctl --failed
systemctl --user --failed
```

NVIDIA:

```bash
nvidia-smi
cat /sys/module/nvidia_drm/parameters/modeset
```

SDDM:

```bash
systemctl status sddm --no-pager
journalctl -b -u sddm --no-pager
```

Remote access:

```bash
tailscale status
systemctl --user status app-dev.lizardbyte.app.Sunshine --no-pager
```

Timeshift:

```bash
sudo timeshift --list
```

---

## 20. Maintenance checklist

Before a major Arch update:

```bash
sudo timeshift \
    --create \
    --comments "Before Arch upgrade"

sudo pacman -Syu
yay -Syu
```

Do not perform partial Arch upgrades.

After kernel/NVIDIA/display-manager updates:

```bash
sudo reboot
```

Then verify:

```bash
systemctl --failed
nvidia-smi
systemctl status sddm --no-pager
```

Before a major repository change:

```bash
cd "$HOME/dotfiles"

git status --short
git diff --check

./scripts/stow-preflight.sh
./scripts/check-desktop-config.sh
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen

hyprctl configerrors
```

Before committing:

```bash
git add -A
git diff --cached --check
git diff --cached --stat
git diff --cached
```

Before merging a substantial change:

- Create a Timeshift snapshot.
- Test affected applications.
- Test Hyprlock/Hypridle.
- Test Waybar/Wofi.
- Test Kitty/Neovim.
- Test SDDM logout/login.
- Validate both package profiles.
- Check for secrets.
- Keep personal backups outside the repository.

A stable `main` should represent a configuration that can be deployed on a
fresh Arch installation without relying on undocumented manual state.
