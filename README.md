# Arch Linux / Hyprland Dotfiles

A reproducible Arch Linux workstation configuration built around Hyprland,
GNU Stow, machine-specific hardware profiles, explicit package manifests,
validation scripts, and a documented Git workflow.

This repository is designed to remain understandable and rebuildable months or
years later without relying on shell history or memory.

> [!IMPORTANT]
> Clone this repository at `~/dotfiles`. Several scripts and configuration
> files intentionally rely on that location.

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
11. [Installing and recording a new package](#11-installing-and-recording-a-new-package)
12. [Removing a package](#12-removing-a-package)
13. [Adding a new application configuration to Stow](#13-adding-a-new-application-configuration-to-stow)
14. [Remote access](#14-remote-access)
15. [Idle locking and session security](#15-idle-locking-and-session-security)
16. [XDG user directories](#16-xdg-user-directories)
17. [Git workflow](#17-git-workflow)
18. [Rollback and recovery](#18-rollback-and-recovery)
19. [Diagnostics](#19-diagnostics)
20. [Maintenance checklist](#20-maintenance-checklist)

---

## 1. Goals and design principles

The repository has the following goals:

1. Reconstruct the workstation on a clean Arch Linux installation.
2. Keep selected configuration files under version control.
3. Separate common configuration from machine-specific configuration.
4. Separate official repository packages from AUR packages.
5. Avoid unmanaged symbolic links.
6. Detect Stow conflicts before changing the live desktop.
7. Validate package names before migration.
8. Keep the previous computer operational during a migration.
9. Make package additions and removals reproducible.
10. Avoid storing credentials, browser profiles, personal data, or secrets.
11. Keep risky actions explicit rather than silently enabling services.
12. Provide a clear recovery path when a configuration change fails.

This repository is not a backup of the entire home directory. It contains only
selected configuration, scripts, package manifests, documentation, and
non-sensitive visual assets.

---

## 2. Repository layout

```text
dotfiles/
├── configs/
│   ├── hypr/
│   │   └── .config/hypr/
│   ├── kitty/
│   │   └── .config/kitty/
│   ├── nvim/
│   │   └── .config/nvim/
│   ├── waybar/
│   │   └── .config/waybar/
│   ├── wofi/
│   │   └── .config/wofi/
│   └── xdg-user-dirs/
│       └── .config/
├── docs/
├── install/
│   └── install.sh
├── packages/
│   ├── common/
│   ├── features/
│   ├── hardware/
│   ├── profiles/
│   └── aur/
│       ├── optional/
│       └── profiles/
├── scripts/
├── wallpapers/
├── .gitignore
└── README.md
```

### `configs/`

Each direct child of `configs/` is a GNU Stow package. The package reproduces
the target path relative to `$HOME`.

Example:

```text
configs/hypr/.config/hypr/hyprland.conf
```

is deployed as:

```text
~/.config/hypr/hyprland.conf
```

### `packages/`

This directory is the only active source of truth for installed packages.
Historical package inventories may remain under `docs/`, but installation
scripts do not read them.

### `install/`

Contains the high-level installation script for a clean Arch installation.

### `scripts/`

Contains tools for package resolution, package registration, machine
selection, Stow deployment, validation, and remote-access control.

### `docs/`

Contains supporting technical documentation and historical migration records.

### `wallpapers/`

Contains shared visual resources used by Hyprpaper or Hyprlock. Only
non-sensitive images should be stored here.

---

## 3. Security and privacy model

This is a public dotfiles repository. Never commit:

```text
~/.ssh/
~/.gnupg/
~/.password-store/
private keys
recovery codes
API keys
access tokens
Tailscale authentication keys
Sunshine credentials
browser profiles
browser cookies
Wi-Fi credentials
VPN configuration containing credentials
password databases
.env files
personal documents
shell history
application databases
```

The `.gitignore` reduces accidental exposure, but it is not a security
boundary. A tracked file remains tracked after a later `.gitignore` change.

### Before every commit

Inspect names:

```bash
git status --short
git diff --cached --name-only
```

Inspect content:

```bash
git diff --cached
```

Search suspicious file names:

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

A match is not automatically a secret, but every match must be reviewed.

### Scan the current tree for common secret formats

```bash
secret_pattern='BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|tskey-[A-Za-z0-9-]+|xox[baprs]-[A-Za-z0-9-]+'

git grep -nEI "$secret_pattern" -- . || true
```

### Scan all Git history

```bash
git rev-list --all |
while IFS= read -r commit; do
    git grep -nEI "$secret_pattern" "$commit" -- . 2>/dev/null || true
done |
sort -u
```

Deleting a secret in a later commit does not remove it from earlier commits.
A leaked secret must be revoked first.

### Images and metadata

A photograph may expose identity, device model, date, or GPS metadata.

```bash
find configs wallpapers \
    -type f \
    \( -iname '*.jpg' -o \
       -iname '*.jpeg' -o \
       -iname '*.png' -o \
       -iname '*.webp' \) \
    -print
```

With ExifTool installed:

```bash
find configs wallpapers \
    -type f \
    \( -iname '*.jpg' -o \
       -iname '*.jpeg' -o \
       -iname '*.png' -o \
       -iname '*.webp' \) \
    -exec exiftool -a -G1 -s {} +
```

Review `GPSLatitude`, `GPSLongitude`, `Make`, `Model`, `SerialNumber`,
`OwnerName`, `DateTimeOriginal`, and `Location`.

`profile.jpg` must only be committed when it is intentionally public. A generic
avatar is safer.

### AUR trust boundary

AUR packages are not official Arch repository packages. Their PKGBUILDs and
install scripts execute with the current user's privileges.

Before installing or updating an AUR package:

```bash
yay -Si package-name
yay -G package-name
less package-name/PKGBUILD
```

Review source URLs, checksums, `prepare()`, `build()`, `package()`, `.install`
scripts, and changes shown by the AUR helper. Never run `makepkg` as root.

---

## 4. GNU Stow configuration deployment

The Stow directory is:

```text
~/dotfiles/configs
```

The deployment target is:

```text
$HOME
```

### Validate all packages

```bash
cd "$HOME/dotfiles"
./scripts/stow-preflight.sh
```

### Simulate one package manually

```bash
stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    waybar
```

### Deploy or update one package

```bash
./scripts/stow-config.sh waybar
```

### Remove links belonging to one package

```bash
./scripts/unstow-config.sh waybar
```

Unstowing removes links managed by Stow. It does not delete the real files
inside the repository.

### Understanding conflicts

```text
existing target is not owned by stow
```

means a real file, directory, or manually created link already occupies the
target path. Do not use `stow --adopt` without understanding that it can move
target files into the repository.

Safe procedure:

```bash
backup="$HOME/dotfiles-backup/manual-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/waybar" "$backup/waybar-copy"
mv "$HOME/.config/waybar" "$backup/waybar-original"

./scripts/stow-config.sh waybar
```

Check repository-related broken links:

```bash
find "$HOME/.config" \
    -xtype l \
    -lname '*dotfiles*' \
    -print
```

Chrome/Chromium-style `SingletonLock` and `SingletonCookie` links are
application runtime locks and are not Stow diagnostics.

---

## 5. Package manifest architecture

Official packages are resolved from:

```text
packages/profiles/<profile>.txt
```

AUR packages are resolved from:

```text
packages/aur/profiles/<profile>.txt
```

Current profiles:

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

### Official package categories

`packages/common/` contains packages shared by all machines:

```text
00-base.txt
01-network-security.txt
02-audio-media.txt
03-hyprland.txt
04-bluetooth.txt
05-cli.txt
06-storage-filesystems.txt
07-applications.txt
08-printing.txt
09-power-maintenance.txt
10-fonts.txt
```

`packages/features/` contains optional or purpose-specific groups.

`packages/hardware/` contains machine-dependent drivers and utilities.

### AUR categories

`packages/aur/common.txt` contains shared AUR packages.

`packages/aur/optional/` contains optional AUR features.

`packages/aur/profiles/` defines which AUR manifests belong to each machine.

### Historical inventories

Files such as:

```text
docs/explicit-packages-before-refactor.txt
docs/orphans-before-refactor.txt
```

are historical records only. Do not edit them merely to match active
manifests.

---

## 6. Machine-specific Hyprland profiles

Monitor configuration is not stored directly in the common `hyprland.conf`.

Available profiles:

```text
~/.config/hypr/machines/amd-current.conf
~/.config/hypr/machines/omen.conf
```

The active profile is selected through:

```text
~/.config/hypr/machine.conf
```

That selector is a local symbolic link and is intentionally ignored by Git.

Select a machine:

```bash
cd "$HOME/dotfiles"
./scripts/select-machine.sh amd-current
./scripts/select-machine.sh omen
```

Discover output names and modes:

```bash
hyprctl monitors all
```

Apply changes:

```bash
hyprctl reload
hyprctl configerrors
```

Never assume two machines use the same names such as `eDP-1`, `HDMI-A-1`, or
`DP-1`.

---

## 7. Default applications

### Web browser: Firefox

Fresh installations use Firefox. Google Chrome is intentionally absent from
active package manifests. This affects future installations only and does not
uninstall Chrome from an existing machine.

Set Firefox:

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
xdg-mime query default text/html
xdg-mime query default x-scheme-handler/http
xdg-mime query default x-scheme-handler/https
```

### PDF and document reader: Okular

Okular is the single document reader because it supports intensive daily work,
annotations, highlighting, forms, signatures, indexes, thumbnails, printing,
text selection, and multiple document formats.

```bash
xdg-mime default org.kde.okular.desktop application/pdf
xdg-mime query default application/pdf
xdg-open document.pdf
```

Okular's generated user-state files are not versioned unless a future review
identifies specific portable preferences worth keeping.

---

## 8. Installing a new computer

### 8.1 Back up information that does not belong in Git

Store personal documents, SSH/GPG keys, recovery codes, browser data, password
databases, application licenses, unversioned configurations, disk information,
bootloader configuration, and Btrfs layout separately.

Useful inventory commands:

```bash
lsblk -f
lspci -nnk
lsusb
findmnt
sudo btrfs subvolume list /
```

Review output before publishing it.

### 8.2 Complete a minimal Arch installation

The new system must have a bootable installation, a non-root user, working
`sudo`, network connectivity, `git`, and correctly configured Pacman
repositories.

### 8.3 Enable Multilib

Edit:

```bash
sudoedit /etc/pacman.conf
```

Uncomment:

```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Update and verify:

```bash
sudo pacman -Syu
pacman-conf --repo-list | grep -x multilib
```

### 8.4 Clone the repository

```bash
sudo pacman -S --needed git

git clone \
    https://github.com/joansr27/dotfiles.git \
    "$HOME/dotfiles"

cd "$HOME/dotfiles"
git switch main
git pull --ff-only
```

### 8.5 Inspect manifests

```bash
./scripts/resolve-packages.sh omen
./scripts/resolve-aur-packages.sh omen
./scripts/validate-packages.sh omen
```

Review AUR PKGBUILDs before installation.

### 8.6 Run the installer

```bash
./install/install.sh omen
```

or:

```bash
./install/install.sh amd-current
```

The installer verifies Arch, resolves the profile, checks Multilib, updates the
system, installs official and AUR packages, selects the machine profile,
creates user directories, validates Stow conflicts, deploys configurations,
sets Firefox as the browser, and sets Okular as the PDF reader.

It intentionally does not enable services automatically.

### 8.7 Enable services explicitly

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now firewalld
sudo systemctl enable --now sddm
```

Inspect each service with `systemctl status`.

### 8.8 Configure Tailscale

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
tailscale status
```

Never store reusable Tailscale authentication keys in the repository.

### 8.9 Configure Sunshine

The repository does not provide a custom Sunshine systemd unit. It uses the
unit installed by the Sunshine package.

```bash
systemctl --user start app-dev.lizardbyte.app.Sunshine
systemctl --user status app-dev.lizardbyte.app.Sunshine
systemctl --user cat app-dev.lizardbyte.app.Sunshine
```

Do not expose Sunshine through public router port forwarding. Use Tailscale.

### 8.10 Configure displays and backlight

```bash
hyprctl monitors all
nvim "$HOME/.config/hypr/machines/omen.conf"
hyprctl reload
hyprctl configerrors

ls -l /sys/class/backlight
brightnessctl --list
```

Waybar lets its backlight module select an appropriate device rather than
hard-coding the AMD laptop device.

### 8.11 Final validation

```bash
cd "$HOME/dotfiles"

./scripts/stow-preflight.sh
./scripts/check-desktop-config.sh
./scripts/validate-packages.sh omen

hyprctl configerrors
pgrep -a waybar
pgrep -a hyprpaper
pgrep -a hypridle
```

Log out and back in before considering the migration complete.

---

## 9. Migrating an existing Arch installation

Do not migrate every configuration at once.

### 9.1 Create backups

```bash
backup="$HOME/dotfiles-backup/existing-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/hypr" "$backup/hypr"
cp -aL "$HOME/.config/waybar" "$backup/waybar"
cp -aL "$HOME/.config/kitty" "$backup/kitty"
cp -aL "$HOME/.config/nvim" "$backup/nvim"
cp -aL "$HOME/.config/wofi" "$backup/wofi"
```

### 9.2 Migrate one package at a time

```bash
stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    waybar

./scripts/stow-config.sh waybar
```

Test the application before continuing.

### 9.3 Special care for Hyprland

Keep a terminal open and do not log out while `~/.config/hypr` is absent.

```bash
test -r "$HOME/.config/hypr/hyprland.conf"
ls -ld "$HOME/.config/hypr"
readlink -f "$HOME/.config/hypr"

hyprctl reload
hyprctl configerrors
```

If Hyprland suddenly uses an English keyboard, reversed scrolling, different
rounding, or incorrect scaling, it is probably not reading the intended file.

---

## 10. Updating an existing configuration

### 10.1 Start from updated `main`

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
```

### 10.2 Create a branch

```bash
git switch -c feature/waybar-network-tooltip
```

Do not develop directly on `main`.

### 10.3 Edit

Both paths refer to the same Stow-managed file:

```bash
nvim "$HOME/.config/waybar/config.jsonc"

nvim \
    "$HOME/dotfiles/configs/waybar/.config/waybar/config.jsonc"
```

### 10.4 Test

```bash
hyprctl reload
hyprctl configerrors

pkill waybar
waybar \
    -l debug \
    -c "$HOME/.config/waybar/config.jsonc" \
    -s "$HOME/.config/waybar/style.css"

kitty --config "$HOME/.config/kitty/kitty.conf"
nvim --headless '+qa'
```

Validate Bash scripts:

```bash
find scripts install \
    -type f \
    -name '*.sh' \
    -print0 |
while IFS= read -r -d '' script; do
    bash -n "$script"
done
```

### 10.5 Review, stage, commit, and push

```bash
git status --short
git diff --check
git diff --stat
git diff

git add path/to/modified/file

git diff --cached --check
git diff --cached --stat
git diff --cached

git commit -m "feat: improve Waybar network tooltip"
git push -u origin HEAD
```

For session-start configuration, test a full logout/login before merging.

---

## 11. Installing and recording a new package

Installing a package on one computer is not enough. It must be classified and
recorded so a future installation reproduces it.

The recommended workflow uses `scripts/add-package.sh`.

### 11.1 Determine the source

```bash
pacman -Si package-name
yay -Si package-name
```

Never record the same package in official and AUR manifests.

### 11.2 Create a package branch

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
git switch -c packages/add-package-name
```

### 11.3 Common official application

```bash
./scripts/add-package.sh \
    --source official \
    --package firefox \
    --manifest common/07-applications.txt
```

The common applications manifest is already referenced by both profiles.

### 11.4 New official feature manifest

```bash
./scripts/add-package.sh \
    --source official \
    --package package-name \
    --manifest features/example-feature.txt \
    --profiles amd-current,omen
```

The script validates the package, checks official/AUR duplication, installs it
unless `--no-install` is used, creates and sorts the manifest, adds it to the
requested profiles, resolves affected profiles, and shows the Git diff.

### 11.5 Hardware-specific official package

```bash
./scripts/add-package.sh \
    --source official \
    --package package-name \
    --manifest hardware/omen-intel-nvidia.txt
```

or:

```bash
./scripts/add-package.sh \
    --source official \
    --package package-name \
    --manifest hardware/amd-laptop.txt
```

### 11.6 Common AUR package

```bash
./scripts/add-package.sh \
    --source aur \
    --package package-name \
    --manifest common.txt
```

Inspect the PKGBUILD and changes shown by `yay` before accepting.

### 11.7 Optional AUR feature

```bash
./scripts/add-package.sh \
    --source aur \
    --package package-name \
    --manifest optional/example-feature.txt \
    --profiles omen
```

### 11.8 Preview only

```bash
./scripts/add-package.sh \
    --dry-run \
    --source official \
    --package package-name \
    --manifest common/07-applications.txt
```

### 11.9 Record without installing locally

```bash
./scripts/add-package.sh \
    --no-install \
    --source official \
    --package package-name \
    --manifest hardware/omen-intel-nvidia.txt
```

### 11.10 Validate

```bash
./scripts/resolve-packages.sh amd-current
./scripts/resolve-packages.sh omen
./scripts/resolve-aur-packages.sh amd-current
./scripts/resolve-aur-packages.sh omen
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen
```

Official/AUR overlap:

```bash
comm -12 \
    <(./scripts/resolve-packages.sh omen | sort -u) \
    <(./scripts/resolve-aur-packages.sh omen | sort -u)
```

It should print nothing.

### 11.11 Review and commit

```bash
git status --short
git diff --check
git diff

git add packages/ scripts/add-package.sh

git diff --cached --check
git diff --cached --stat
git diff --cached

git commit -m "packages: add package-name"
git push -u origin HEAD
```

### 11.12 Manual fallback

Official common package:

```bash
printf '%s\n' package-name \
    >> packages/common/07-applications.txt

sort -u \
    -o packages/common/07-applications.txt \
    packages/common/07-applications.txt

sudo pacman -S --needed package-name
```

AUR common package:

```bash
printf '%s\n' package-name \
    >> packages/aur/common.txt

sort -u \
    -o packages/aur/common.txt \
    packages/aur/common.txt

yay -S --needed package-name
```

For a newly created manifest, add its relative path to the appropriate profile.

---

## 12. Removing a package

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git switch -c packages/remove-package-name
```

Remove it from the active manifest:

```bash
sed -i \
    '/^package-name$/d' \
    packages/common/07-applications.txt
```

Uninstall only when appropriate for the current machine:

```bash
sudo pacman -Rns package-name
```

Remove Stow configuration when no longer used:

```bash
./scripts/unstow-config.sh application-name
git rm -r configs/application-name
```

Validate and commit:

```bash
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen

git add -A
git diff --cached
git commit -m "packages: remove package-name"
git push -u origin HEAD
```

---

## 13. Adding a new application configuration to Stow

Assume the application uses `~/.config/example/`.

```bash
backup="$HOME/dotfiles-backup/example-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp -aL "$HOME/.config/example" "$backup/example-copy"

mkdir -p "$HOME/dotfiles/configs/example/.config"
cp -a \
    "$HOME/.config/example" \
    "$HOME/dotfiles/configs/example/.config/example"

mv \
    "$HOME/.config/example" \
    "$backup/example-original"

stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    example

./scripts/stow-config.sh example
```

Test the application, then commit:

```bash
git add configs/example
git diff --cached
git commit -m "config: manage example with Stow"
git push -u origin HEAD
```

Special targets such as individual files directly under `~/.config` require a
custom Stow package layout.

---

## 14. Remote access

The design uses Tailscale for private connectivity and Sunshine as the
streaming host. The repository does not contain a custom Sunshine systemd unit.

Start:

```bash
cd "$HOME/dotfiles"
./scripts/remote-on.sh
```

Equivalent commands:

```bash
sudo systemctl start tailscaled
systemctl --user start app-dev.lizardbyte.app.Sunshine
```

Stop:

```bash
./scripts/remote-off.sh
```

Status:

```bash
tailscale status
systemctl --user status app-dev.lizardbyte.app.Sunshine
```

Do not forward Sunshine ports publicly. Keep Sunshine updated, protect its
administration interface, and do not commit credentials.

---

## 15. Idle locking and session security

Hypridle is installed from the official repository and started by Hyprland:

```text
exec-once = hypridle
```

Configuration:

```text
~/.config/hypr/hypridle.conf
```

The intended behavior is to lock after inactivity, lock before external sleep,
turn displays off after locking, and restore displays on activity.

Verify:

```bash
pacman -Q hypridle
command -v hypridle
test -r "$HOME/.config/hypr/hypridle.conf"
grep -n '^exec-once = hypridle$' \
    "$HOME/.config/hypr/hyprland.conf"
```

Start manually in the current session:

```bash
pkill -x hypridle 2>/dev/null || true
hypridle > /tmp/hypridle.log 2>&1 &
disown
sleep 1
pgrep -a hypridle
```

Test locking:

```bash
loginctl lock-session
```

After unlocking:

```bash
pgrep -a hypridle
cat /tmp/hypridle.log
```

Do not simultaneously enable a Hypridle user service while also starting it
with `exec-once`, unless the startup design is intentionally changed.

---

## 16. XDG user directories

The `xdg-user-dirs` Stow package manages:

```text
~/.config/user-dirs.conf
~/.config/user-dirs.dirs
```

It does not create `~/.config/xdg`.

```bash
mkdir -p "$HOME/Desktop" "$HOME/Downloads"

xdg-user-dir DESKTOP
xdg-user-dir DOWNLOAD
xdg-user-dir DOCUMENTS
xdg-user-dir PICTURES
```

The current design keeps `Desktop` and `Downloads` separate and redirects other
standard categories to `Downloads`.

Do not run `xdg-user-dirs-update` without reviewing whether it may rewrite
files managed by Stow.

---

## 17. Git workflow

Update local `main`:

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
```

Create a branch:

```bash
git switch -c type/descriptive-name
```

Suggested prefixes:

```text
feature/
fix/
packages/
config/
docs/
refactor/
security/
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

Inspect staged content:

```bash
git diff --cached --check
git diff --cached --stat
git diff --cached
```

Commit and push:

```bash
git commit -m "type: concise description"
git push -u origin HEAD
```

Compare with `main`:

```bash
git diff --stat main...HEAD
git diff --name-status main...HEAD
git diff main...HEAD
```

Do not force-push shared or public history unless history rewriting is
deliberate and coordinated.

---

## 18. Rollback and recovery

Discard an unstaged file change:

```bash
git restore path/to/file
```

Unstage:

```bash
git restore --staged path/to/file
```

Restore from `main`:

```bash
git show main:path/to/file > path/to/file
```

Revert a published commit:

```bash
git revert COMMIT_SHA
git push
```

Temporarily remove and redeploy a Stow package:

```bash
./scripts/unstow-config.sh waybar
./scripts/stow-config.sh waybar
```

Recover a missing Hyprland link:

```bash
test -r \
    "$HOME/dotfiles/configs/hypr/.config/hypr/hyprland.conf"

mkdir -p "$HOME/.config"
ln -s \
    "$HOME/dotfiles/configs/hypr/.config/hypr" \
    "$HOME/.config/hypr"

hyprctl reload
hyprctl configerrors
```

Later remove the manual link and let Stow recreate it.

---

## 19. Diagnostics

```bash
./scripts/check-desktop-config.sh
./scripts/stow-preflight.sh
./scripts/validate-packages.sh omen

hyprctl reload
hyprctl configerrors

waybar \
    -l debug \
    -c "$HOME/.config/waybar/config.jsonc" \
    -s "$HOME/.config/waybar/style.css"

pgrep -a waybar
pgrep -a hyprpaper
pgrep -a hypridle

systemctl --failed
systemctl --user --failed

xdg-settings get default-web-browser
xdg-mime query default application/pdf
```

Broken repository links:

```bash
find "$HOME/.config" \
    -xtype l \
    -lname '*dotfiles*' \
    -print
```

When Hyprland appears to use defaults:

```bash
ls -ld "$HOME/.config/hypr"
readlink -f "$HOME/.config/hypr"
test -r "$HOME/.config/hypr/hyprland.conf"
hyprctl reload
hyprctl configerrors
```

---

## 20. Maintenance checklist

Before publishing a major change:

```bash
cd "$HOME/dotfiles"

git status --short
git diff --check

find scripts install \
    -type f \
    -name '*.sh' \
    -print0 |
while IFS= read -r -d '' script; do
    bash -n "$script"
done

./scripts/stow-preflight.sh
./scripts/check-desktop-config.sh
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen

hyprctl reload
hyprctl configerrors

pgrep -a waybar
pgrep -a hyprpaper
pgrep -a hypridle
```

Before committing:

```bash
git add -A

git diff --cached --check
git diff --cached --stat
git diff --cached
```

Before merging a substantial desktop change:

- test affected applications;
- test Hyprlock;
- test idle locking;
- test Waybar and Wofi;
- test Kitty and Neovim;
- test Firefox associations;
- test Okular associations;
- log out and back in;
- check broken links;
- validate both package profiles;
- inspect all staged files for secrets;
- keep a backup outside the repository.

The stable branch should only receive changes that pass these checks.
