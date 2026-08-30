# Arch Linux / Hyprland Dotfiles

A reproducible Arch Linux workstation configuration built around Hyprland,
GNU Stow, machine-specific hardware profiles, official Arch package manifests,
validation scripts, and Timeshift recovery. Remote desktop configuration is
deliberately kept outside the current repository.

> [!IMPORTANT]
> Clone this repository at `~/dotfiles`. Several scripts and configuration
> files intentionally rely on that location.

> [!TIP]
> Planning to reproduce this workstation on a Windows machine? Read
> **[Windows 11 + Arch Linux dual boot with `archinstall`](docs/archinstall-windows-dual-boot.md)**
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
14. [Remote access policy](#14-remote-access-policy)
15. [Idle locking and session security](#15-idle-locking-and-session-security)
16. [XDG user directories](#16-xdg-user-directories)
17. [Initial GitHub and SSH configuration](#17-initial-github-and-ssh-configuration)
18. [Git workflow](#18-git-workflow)
19. [Timeshift snapshots and system recovery](#19-timeshift-snapshots-and-system-recovery)
20. [Diagnostics](#20-diagnostics)
21. [Maintenance checklist](#21-maintenance-checklist)
22. [Changing wallpapers and visual assets](#22-changing-wallpapers-and-visual-assets)

---

## 1. Goals and design principles

The repository aims to:

1. Reconstruct the workstation on a clean Arch Linux installation.
2. Keep selected configuration under version control.
3. Separate common configuration from hardware-specific configuration.
4. Keep package selection restricted to enabled official Arch repositories.
5. Deploy configuration through GNU Stow rather than unmanaged links.
6. Detect Stow conflicts before changing the live desktop.
7. Validate packages before migration.
8. Keep machine-specific graphics/monitor rules isolated.
9. Keep risky service activation explicit.
10. Avoid storing secrets or private application state.
11. Provide predictable rollback paths with Git and Timeshift.
12. Keep remote desktop implementation separate from the base workstation configuration.

The repository is **not** a full home-directory backup.

---

## 2. Repository layout

```text
dotfiles/
├── assets/
│   ├── hyprlock.*
│   ├── profile.*
│   └── wallpaper.*
├── configs/
│   ├── hypr/
│   ├── kitty/
│   ├── nvim/
│   ├── waybar/
│   ├── wofi/
│   └── xdg-user-dirs/
├── docs/
│   └── archinstall-windows-dual-boot.md
├── install/
│   └── install.sh
├── packages/
│   ├── common/
│   ├── features/
│   ├── hardware/
│   └── profiles/
├── scripts/
│   └── ...
├── system/
│   └── omen/
│       └── etc/
│           └── systemd/
│               └── logind.conf.d/
│                   └── 60-lid-lock.conf
├── wallpapers/
├── .gitignore
└── README.md
```

### `configs/`

Each direct child is a Stow package. For example:

```text
configs/hypr/.config/hypr/hyprland.lua
```

is deployed into:

```text
~/.config/hypr/hyprland.lua
```

### `packages/`

Active source of truth for package selection.

### `install/`

Contains the high-level clean-install migration script.

### `scripts/`

Contains package resolvers, validators, Stow helpers, machine selection,
desktop-asset preparation, and workstation helper scripts.

### `system/`

Contains machine-specific system configuration that requires root privileges
and therefore is not deployed through the user-level GNU Stow configuration.

Applicable files are copied into their system locations by the installer using
`sudo install`. This keeps `/etc` configuration root-owned instead of linking
root-consumed configuration to the user-writable repository.

### `docs/`

Supporting documentation and dual boot guide.

### `assets/`

Contains the three active source images used by the desktop:

```text
assets/
├── wallpaper.*
├── hyprlock.*
└── profile.*
```

The file extension is intentionally not fixed. Each logical asset must have
exactly one readable source image whose basename is `wallpaper`, `hyprlock`,
or `profile`.

For example, this is valid:

```text
assets/
├── wallpaper.png
├── hyprlock.jpeg
└── profile.webp
```

Image preparation is handled by:

```text
scripts/prepare-desktop-assets.sh
```

The script uses ImageMagick to resolve the source images and normalizes them
into stable PNG files under:

```text
~/.cache/dotfiles/assets/
├── wallpaper.png
├── hyprlock.png
└── profile.png
```

Hyprpaper and Hyprlock reference these normalized cache files rather than the
source files in the repository. This separates desktop configuration from the
original image format.

The generated cache is runtime state and is not stored in Git.

If an input contains multiple frames, such as an animated GIF, only the first
frame is used. Animated wallpaper or lock-screen playback is therefore not
provided by this mechanism.

More than one readable source file for the same logical asset is considered an
error. For example, `wallpaper.jpg` and `wallpaper.png` must not coexist under
`assets/`.

See [Changing wallpapers and visual assets](#22-changing-wallpapers-and-visual-assets)
for the complete workflow.

### `wallpapers/`

Contains the inactive wallpaper/image library.

The maintainer does not claim authorship or copyright ownership of third-party
visual assets unless explicitly stated otherwise. No license to those images
is granted by this repository.

See [`wallpapers/LICENSE`](wallpapers/LICENSE) for the full third-party asset
notice. The notice also applies to the active images under `assets/`.

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
remote-access credentials
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

### Scan the current repository for common secret formats

A staged-diff check protects future commits, but it does not inspect files that
are already committed.

Run:

```bash
cd "$HOME/dotfiles"

secret_pattern='BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+|tskey-[A-Za-z0-9-]+|xox[baprs]-[A-Za-z0-9-]+'

git grep -nEI "$secret_pattern" -- . || true
```

No output is the expected result.

This catches several common private-key, GitHub, Tailscale, AWS, and Slack
credential formats, but it is not proof that every possible secret format is
absent.

### Scan the complete Git history

Removing a credential in a later commit does not remove it from older commits.

Scan every reachable commit:

```bash
cd "$HOME/dotfiles"

secret_pattern='BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+|tskey-[A-Za-z0-9-]+|xox[baprs]-[A-Za-z0-9-]+'

git rev-list --all |
while IFS= read -r commit; do
    git grep -nEI "$secret_pattern" "$commit" -- . 2>/dev/null || true
done |
sort -u
```

No output is the expected result.

If a real credential is ever found in Git history, revoke or rotate the
credential **before** attempting to rewrite Git history.

### Review image metadata

Images may contain metadata such as camera/device information, timestamps,
owner names, or GPS coordinates.

The repository installs ExifTool through the `perl-image-exiftool` Arch
package.

Audit all tracked-style visual assets with:

```bash
cd "$HOME/dotfiles"

find assets wallpapers \
    -type f \
    \( -iname '*.png' -o \
       -iname '*.jpg' -o \
       -iname '*.jpeg' -o \
       -iname '*.webp' -o \
       -iname '*.gif' -o \
       -iname '*.avif' -o \
       -iname '*.heic' -o \
       -iname '*.heif' -o \
       -iname '*.bmp' -o \
       -iname '*.tif' -o \
       -iname '*.tiff' -o \
       -iname '*.jxl' \) \
    -exec exiftool -a -G1 -s {} +
```

Pay particular attention to:

```text
GPSLatitude
GPSLongitude
GPSPosition
Make
Model
SerialNumber
OwnerName
Artist
DateTimeOriginal
Location
```

Metadata is not automatically sensitive. Attribution, copyright, and license
metadata may be useful and should not be removed blindly.

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

All packages managed by this repository must be available from an enabled
official Arch Linux Pacman repository.

Package manifests live under:

```text
packages/
├── common/
├── features/
├── hardware/
└── profiles/
```

Current machine profiles:

```text
amd-current
omen
```

Resolve a profile with:

```bash
./scripts/resolve-packages.sh amd-current
./scripts/resolve-packages.sh omen
```

Validate a profile with:

```bash
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen
```

Validation enforces three invariants:

- every package manifest is alphabetically sorted;
- every resolved package exists in an enabled Pacman repository;
- no foreign installed packages are present.

Therefore, on a repository-compliant installation:

```bash
pacman -Qm
```

must produce no output.

---

## 6. Machine-specific Hyprland profiles

Machine configuration is selected through:

```text
~/.config/hypr/machine.lua
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

### Gwenview

Gwenview is the default image viewer.

```bash
for mime in \
    image/avif \
    image/bmp \
    image/gif \
    image/heic \
    image/heif \
    image/jpeg \
    image/png \
    image/svg+xml \
    image/tiff \
    image/webp
do
    xdg-mime default \
        org.kde.gwenview.desktop \
        "$mime"
done

```

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
[`archinstall-windows-dual-boot.md`](docs/archinstall-windows-dual-boot.md).

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
    https://github.com/<OWNER>/<REPOSITORY>.git \
    "$HOME/dotfiles"

cd "$HOME/dotfiles"
git switch main
git pull --ff-only
```

Inspect:

```bash
./scripts/resolve-packages.sh omen
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
sudo systemctl enable --now cronie
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable sddm
```

Remote desktop is not configured by this repository. External KVM hardware
such as PiKVM is the preferred future architecture. `tailscale` and `wayvnc`
are retained as optional official packages but remain unconfigured.

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
test -r "$HOME/.config/hypr/hyprland.lua"
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

Use the repository helper for official Arch packages:

```bash
./scripts/add-package.sh \
    --package firefox \
    --manifest common/07-applications.txt
```

For a feature manifest that should be enabled for multiple profiles:

```bash
./scripts/add-package.sh \
    --package package-name \
    --manifest features/example.txt \
    --profiles amd-current,omen
```

Only packages available from an enabled Pacman repository are accepted.

The helper automatically sorts modified package manifests and profile files.

After changing the package set, validate both profiles:

```bash
./scripts/validate-packages.sh amd-current
./scripts/validate-packages.sh omen
```

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

## 14. Remote access policy

Remote desktop is intentionally **not implemented by this repository**.

The preferred architecture is an external hardware KVM solution such as
**PiKVM**. This keeps remote keyboard, video, and mouse access separate from
the Arch desktop software stack.

PiKVM configuration is outside the current scope of this repository. It will
be documented separately after the hardware workflow has been tested.

The package profiles currently retain two official Arch packages as optional
software building blocks:

```text
tailscale
wayvnc
```

They are intentionally left **unconfigured**. Their installation does not mean
that a software remote-desktop workflow is currently supported or maintained
by this repository.

There are currently:

- no remote-access helper scripts;
- no WayVNC configuration;
- no repository-managed Tailscale remote-desktop policy;
- no repository-managed remote-access credentials;
- no remote-desktop router port-forwarding instructions.

A software approach may be evaluated in the future, but it should be treated
as a separate project and documented only after its security model has been
tested.

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

### HP OMEN lid policy

The OMEN installation profile intentionally configures systemd-logind to lock
the session instead of suspending when the laptop lid is closed. Suspend/resume
is currently unreliable on this machine, so the system is shut down manually when
required.

The systemd-logind policy is stored in the repository at:

    system/omen/etc/systemd/logind.conf.d/60-lid-lock.conf

During an OMEN installation:

    ./install/install.sh omen

automatically installs this file to:

    /etc/systemd/logind.conf.d/60-lid-lock.conf

The configured lid behavior is:

    HandleLidSwitch=lock
    HandleLidSwitchExternalPower=lock
    HandleLidSwitchDocked=lock

Closing the lid therefore locks the current session instead of suspending,
hibernating, or shutting down the computer. The internal laptop panel powers
off normally while the lid is physically closed.

Opening the lid restores the display and returns to the locked Hyprlock
session.

Normal idle behavior remains managed separately by Hypridle:

    300 seconds of inactivity -> lock the session
    330 seconds of inactivity -> power off the displays
    user activity             -> power the displays back on

Automatic suspend is intentionally not used on the HP OMEN. This policy can be
revisited in the future if reliable suspend/resume support becomes available.

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

## 17. Initial GitHub and SSH configuration

GitHub authentication is global to the user account, but that does **not**
make the entire home directory part of this Git repository. Git tracks the
working tree whose metadata is stored in `~/dotfiles/.git`.

The procedures below deliberately use an SSH authentication key for Git
operations and GitHub CLI (`gh`) for account authentication.

### 17.1 Existing original repository: authenticate a new machine and reconnect the clone

Use this procedure when the GitHub repository already exists and
`~/dotfiles` is already a clone of that repository.

#### Install Git, GitHub CLI, and OpenSSH

```bash
sudo pacman -S --needed git github-cli openssh
```

Verify:

```bash
git --version
gh --version
ssh -V
```

#### Configure global Git identity and defaults

Set the commit identity:

```bash
git config --global user.name "YOUR NAME"
git config --global user.email "YOUR_GITHUB_EMAIL"
```

A GitHub `noreply` address can be used instead of a personal email address.

Recommended defaults:

```bash
git config --global init.defaultBranch main
git config --global pull.ff only
git config --global push.default simple
```

Review:

```bash
git config --global --list
```

These settings apply to Git globally. They do not define the filesystem
boundary of any repository.

#### Authenticate GitHub CLI and generate the SSH key

Run:

```bash
gh auth login
```

Select:

```text
GitHub.com
→ SSH
→ Generate a new SSH key: Yes
```

When prompted for an SSH-key passphrase:

- enter a passphrase for additional protection; or
- deliberately press Enter twice if an unencrypted private key is acceptable
  for the machine's threat model and passwordless Git use is preferred.

Use a generic, recognizable key title such as:

```text
Arch Linux laptop
```

When asked how GitHub CLI should authenticate, choose:

```text
Paste an authentication token
```

Create a classic Personal Access Token in the GitHub web interface:

```text
GitHub
→ Settings
→ Developer settings
→ Personal access tokens
→ Tokens (classic)
→ Generate new token
→ Generate new token (classic)
```

Give the token a generic device note such as:

```text
Arch Linux laptop
```

Prefer a finite expiration period.

For this GitHub CLI + SSH-key setup, enable:

```text
repo
read:org
gist
admin:public_key
```

The first three cover the normal GitHub CLI token requirements for repository
and account operations. `admin:public_key` is needed here because GitHub CLI
is being allowed to upload/manage the generated SSH authentication key.

Generate the token, copy it once, and paste it directly into the hidden
`gh auth login` prompt.

Never save the token in this repository, a shell script, a dotfile, shell
history, or a plaintext notes file.

#### Verify GitHub CLI and the uploaded SSH key

Run:

```bash
gh auth status
gh ssh-key list
```

The newly generated SSH authentication key should be visible in the account.

Test SSH:

```bash
ssh -T git@github.com
```

On the first connection, OpenSSH may show GitHub's host-key fingerprint and
ask whether to trust the host. Before entering `yes`, compare the displayed
fingerprint with the current official fingerprints published by GitHub:

```text
GitHub Docs
→ Authentication
→ Keeping your account and data secure
→ GitHub's SSH key fingerprints
```

Only accept the host if the fingerprint matches the official documentation.

A successful test ends with a message equivalent to:

```text
You've successfully authenticated, but GitHub does not provide shell access.
```

GitHub intentionally does not provide an interactive SSH shell.

#### Verify that only `~/dotfiles` is the repository working tree

Do **not** run `git init` when `~/dotfiles` was cloned from the existing
repository.

Check:

```bash
cd "$HOME/dotfiles"

git rev-parse --show-toplevel
readlink -f "$(git rev-parse --git-dir)"
```

Expected structure:

```text
/home/<USER>/dotfiles
/home/<USER>/dotfiles/.git
```

Now make sure the home directory itself was never initialized as a repository:

```bash
test -d "$HOME/.git" \
    && echo "WARNING: ~/.git exists" \
    || echo "OK: ~/.git does not exist"
```

Also:

```bash
cd "$HOME"

git rev-parse --show-toplevel 2>/dev/null \
    || echo "OK: HOME is outside any Git repository"
```

Never run:

```bash
git init
```

directly in `$HOME`.

#### Change the existing clone from HTTPS to SSH

Inspect the current remote:

```bash
cd "$HOME/dotfiles"
git remote -v
```

A repository cloned before GitHub authentication may use an HTTPS URL.

Change `origin` to the existing repository's SSH URL:

```bash
git remote set-url origin \
    git@github.com:<OWNER>/<REPOSITORY>.git
```

Verify:

```bash
git remote -v
```

Expected form:

```text
origin  git@github.com:<OWNER>/<REPOSITORY>.git (fetch)
origin  git@github.com:<OWNER>/<REPOSITORY>.git (push)
```

#### Connect local `main` to `origin/main`

Fetch remote metadata:

```bash
git fetch origin
```

Switch to the local main branch:

```bash
git switch main
```

Inspect tracking:

```bash
git branch -vv
```

The local branch should contain:

```text
[origin/main]
```

If it does not:

```bash
git branch --set-upstream-to=origin/main main
```

Verify:

```bash
git rev-parse --abbrev-ref --symbolic-full-name '@{u}'
```

Expected:

```text
origin/main
```

Test read access:

```bash
git fetch origin
```

Test write authentication without sending a new commit:

```bash
git push --dry-run origin main
```

A synchronized repository normally reports:

```text
Everything up-to-date
```

#### Final boundary check

Run:

```bash
cd "$HOME/dotfiles"

git rev-parse --show-toplevel
git remote -v
git branch -vv
git status --short

test -d "$HOME/.git" \
    && echo "WARNING: ~/.git exists" \
    || echo "OK: HOME is not a Git repository"
```

The intended relationship is:

```text
GitHub account
    │
    └── SSH authentication key
            │
            ▼
        github.com
            │
            ▼
       origin/main
            ▲
            │
       local main
            │
            ▼
      ~/dotfiles
            │
            └── .git/
```

Global GitHub authentication does not make `$HOME` a Git working tree.

Stow-managed paths such as:

```text
~/.config/hypr
```

can point into `~/dotfiles` while the Git repository itself remains strictly
rooted at `~/dotfiles`.

### 17.2 Cloned repository: publish a modified version in a new personal GitHub repository

Use this procedure when the repository was cloned from another GitHub account,
will now be customized, and should be published as a new repository owned by
the current GitHub account.

The GitHub/SSH authentication procedure is intentionally repeated so this
section can be followed independently.

#### Configure GitHub authentication

Install:

```bash
sudo pacman -S --needed git github-cli openssh
```

Configure the Git identity:

```bash
git config --global user.name "YOUR NAME"
git config --global user.email "YOUR_GITHUB_EMAIL"

git config --global init.defaultBranch main
git config --global pull.ff only
git config --global push.default simple
```

Authenticate:

```bash
gh auth login
```

Select:

```text
GitHub.com
→ SSH
→ Generate a new SSH key: Yes
→ Enter an SSH-key passphrase, or intentionally leave it blank
→ Give the key a generic device title
→ Paste an authentication token
```

Create the classic Personal Access Token from:

```text
GitHub
→ Settings
→ Developer settings
→ Personal access tokens
→ Tokens (classic)
→ Generate new token
```

Enable:

```text
repo
read:org
gist
admin:public_key
```

Paste the generated token only into the `gh auth login` prompt.

Verify:

```bash
gh auth status
gh ssh-key list
ssh -T git@github.com
```

On the first SSH connection, verify GitHub's host-key fingerprint against
GitHub's current official documentation before accepting it.

#### Verify the local repository boundary

Before changing remotes:

```bash
cd "$HOME/dotfiles"

git rev-parse --show-toplevel
readlink -f "$(git rev-parse --git-dir)"
git status
```

The top-level working tree must be:

```text
/home/<USER>/dotfiles
```

and `$HOME/.git` should not exist:

```bash
test -d "$HOME/.git" \
    && echo "WARNING: ~/.git exists" \
    || echo "OK: ~/.git does not exist"
```

#### Recommended method: preserve the original Git history

A clone already contains a `.git` directory. Therefore, `git init` is **not**
required if the original commit history should be kept.

Inspect the existing remote:

```bash
git remote -v
```

Rename the original repository from `origin` to `upstream`:

```bash
git remote rename origin upstream
```

This preserves the original project as a reference and frees the conventional
name `origin` for the new personal repository.

Verify:

```bash
git remote -v
```

Before publishing, inspect the repository carefully:

```bash
git status --short
git diff --check
git diff
git ls-files | less
```

Review the tracked tree for:

- Private SSH keys.
- Authentication tokens.
- Passwords.
- Recovery keys.
- Private application state.
- Personal documents.
- Machine-specific information that should not be public.

Create the new repository from the existing local Git repository:

```bash
gh repo create <NEW_REPOSITORY_NAME> \
    --public \
    --source=. \
    --remote=origin \
    --push
```

The new repository becomes `origin`, while the original source repository
remains `upstream`.

Verify:

```bash
git remote -v
git branch -vv
git status
```

The expected model is:

```text
origin    → new personal repository
upstream  → original repository
```

Normal future work uses:

```bash
git pull --ff-only origin main
git push origin main
```

The original repository can still be inspected with:

```bash
git fetch upstream
```

Do not merge upstream changes automatically; review them first.

#### Alternative: deliberately start a completely new Git history

Use this only when the new repository should have no commit-history
relationship with the original project.

Do not run `git init` directly over the clone's existing `.git` metadata.
Move the original metadata out of the repository first:

```bash
cd "$HOME/dotfiles"

git rev-parse --show-toplevel
git status

mv \
    "$HOME/dotfiles/.git" \
    "$HOME/dotfiles-original-git-backup"
```

This leaves the working files in place while preserving the original Git
metadata outside the new repository.

Initialize the new history:

```bash
cd "$HOME/dotfiles"

git init
git branch -m main
```

Immediately verify the repository boundary:

```bash
git rev-parse --show-toplevel

test -d "$HOME/.git" \
    && echo "WARNING: ~/.git exists" \
    || echo "OK: ~/.git does not exist"
```

Review the complete tree before staging:

```bash
git status --short
```

Stage:

```bash
git add .
```

Inspect everything that will enter the first commit:

```bash
git diff --cached --check
git diff --cached --stat
git diff --cached --name-only
git diff --cached
```

Search staged filenames for common secret indicators:

```bash
git diff --cached --name-only |
    grep -Ei \
    'secret|token|credential|password|private|\.env|id_rsa|id_ed25519' \
    || true
```

Every match must be reviewed manually.

Create the new initial commit:

```bash
git commit -m "Initial dotfiles import"
```

Create and push the new repository:

```bash
gh repo create <NEW_REPOSITORY_NAME> \
    --public \
    --source=. \
    --remote=origin \
    --push
```

Verify:

```bash
git remote -v
git branch -vv
git status
git rev-parse --show-toplevel
```

Confirm once more that the home directory itself is not a repository:

```bash
test -d "$HOME/.git" \
    && echo "WARNING: ~/.git exists" \
    || echo "OK: HOME is not a Git repository"
```

Keep:

```text
~/dotfiles-original-git-backup
```

until the new GitHub repository has been checked and the old history is
definitely no longer required.

Only then, if appropriate:

```bash
rm -rf "$HOME/dotfiles-original-git-backup"
```

---

## 18. Git workflow

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

## 19. Timeshift snapshots and system recovery

Timeshift is the system rollback layer for this workstation.

It protects the Linux system state. It does **not** replace backups of personal
files and it does not protect against physical SSD failure.

### 19.1 Review Timeshift

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

### 19.2 Create a snapshot

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

### 19.3 Review what a snapshot is for

Timeshift is designed primarily for system files/settings. Do not assume that
documents in `$HOME` are your backup just because a Timeshift snapshot exists.

Keep personal backups separately.

### 19.4 Restore while Arch still boots

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

### 19.5 If the graphical desktop is broken but TTY works

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

### 19.6 If Arch no longer boots

Boot a Linux live environment in UEFI mode.

For this encrypted Btrfs installation:

1. Identify the disk with `lsblk`.
2. Open the LUKS partition.
3. Mount the Btrfs root and boot partitions if manual repair is required.
4. Use a live environment with Timeshift available for an offline Timeshift
   restore, or `arch-chroot` for manual repair.

The complete disk/chroot procedure is documented in
[`archinstall-windows-dual-boot.md`](docs/archinstall-windows-dual-boot.md).

### 19.7 Git rollback versus Timeshift rollback

Use Git when only repository-managed configuration is wrong:

```bash
git restore path/to/file
git revert COMMIT_SHA
```

Use Timeshift when the **installed system state** is broken—for example a
kernel, driver, package, or system-wide configuration change.

---

## 20. Diagnostics

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

No remote-desktop service is configured by this repository. External KVM
hardware such as PiKVM is the preferred future approach. `tailscale` and
`wayvnc` remain optional, unconfigured packages.

Timeshift:

```bash
sudo timeshift --list
```

---

## 21. Maintenance checklist

Before a major Arch update:

```bash
sudo timeshift \
    --create \
    --comments "Before Arch upgrade"

sudo pacman -Syu
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

---

## 22. Changing wallpapers and visual assets

The active desktop images are stored under:

```text
~/dotfiles/assets/
```

There are three logical assets:

```text
wallpaper.*
hyprlock.*
profile.*
```

Their roles are:

- `wallpaper.*` — normal Hyprland desktop wallpaper.
- `hyprlock.*` — Hyprlock background.
- `profile.*` — Hyprlock profile image.


### Image format abstraction

The desktop configuration does not depend on the extension of the source
images.

The resolver accepts the following source extensions, case-insensitively:

```text
.png
.jpg
.jpeg
.webp
.gif
.avif
.heic
.heif
.bmp
.tif
.tiff
.jxl
```

The extension alone is not sufficient. ImageMagick must also be able to decode
the file successfully; unreadable or unsupported files are ignored.

There must be exactly **one readable supported source image per logical asset**.

Valid:

```text
assets/
├── wallpaper.png
├── hyprlock.jpg
└── profile.webp
```

Invalid:

```text
assets/
├── wallpaper.jpg
├── wallpaper.png
├── hyprlock.jpg
└── profile.webp
```

The second example is rejected because two files match the logical
`wallpaper` asset. The resolver deliberately refuses to choose one
arbitrarily.

### Normalized asset cache

Hyprpaper and Hyprlock do not consume the repository source files directly.

Before they are used, the source assets are normalized by:

```bash
~/dotfiles/scripts/prepare-desktop-assets.sh
```

The generated files are stored under:

```text
~/.cache/dotfiles/assets/
├── wallpaper.png
├── wallpaper.sha256
├── hyprlock.png
├── hyprlock.sha256
├── profile.png
└── profile.sha256
```

Hyprpaper and Hyprlock always reference the three `.png` files in this cache.

This provides a stable interface:

```text
source image in arbitrary supported format
                │
                ▼
prepare-desktop-assets.sh
                │
                ▼
normalized PNG in ~/.cache/dotfiles/assets/
                │
        ┌───────┴───────┐
        ▼               ▼
    Hyprpaper        Hyprlock
```

The SHA-256 files record the source state so an unchanged image does not need
to be converted on every Hyprland startup.

The cache is generated runtime state and must not be committed to the
repository.

### Animated and multi-frame images

The normalizer explicitly selects frame `0` from the source image.

Therefore, an animated GIF can be used as an input file:

```text
assets/wallpaper.gif
```

but the generated wallpaper is a static PNG containing the first frame.

This mechanism does not provide animated wallpapers or animated Hyprlock
images.

### Preparing assets manually

Check that all three logical source assets can be resolved:

```bash
cd "$HOME/dotfiles"

./scripts/prepare-desktop-assets.sh --check
```

Generate or refresh the normalized cache:

```bash
./scripts/prepare-desktop-assets.sh
```

Inspect the result:

```bash
ls -lh "$HOME/.cache/dotfiles/assets"
file "$HOME/.cache/dotfiles/assets/"*.png
```

Running the preparation script again without modifying the source images
should report that the cache is already current.

### Changing the desktop wallpaper

Choose an image from the wallpaper library:

```text
~/dotfiles/wallpapers/
```

and place or copy it under `assets/` using the logical basename `wallpaper`
while preserving its original extension.

For example:

```bash
cp \
    "$HOME/dotfiles/wallpapers/Nocturne-of-Steel-and-Glass.png" \
    "$HOME/dotfiles/assets/wallpaper.png"
```

Remove the previous `wallpaper.*` source so that only one readable wallpaper
source remains.

Then regenerate the cache:

```bash
cd "$HOME/dotfiles"
./scripts/prepare-desktop-assets.sh
```

Restart Hyprpaper in the current session:

```bash
pkill hyprpaper
hyprpaper &
disown
```

No Hyprpaper configuration change is required when the source extension
changes.

### Changing the Hyprlock background

Replace the existing `hyprlock.*` source with exactly one new image, for
example:

```text
assets/hyprlock.jpeg
```

Then run:

```bash
cd "$HOME/dotfiles"
./scripts/prepare-desktop-assets.sh
```

The next Hyprlock instance automatically reads:

```text
~/.cache/dotfiles/assets/hyprlock.png
```

No `hyprlock.conf` modification is required.

### Changing the Hyprlock profile picture

Replace the existing `profile.*` source with exactly one new image, for
example:

```text
assets/profile.webp
```

Then run:

```bash
cd "$HOME/dotfiles"
./scripts/prepare-desktop-assets.sh
```

The next Hyprlock instance automatically reads:

```text
~/.cache/dotfiles/assets/profile.png
```

No `hyprlock.conf` modification is required.

### Automatic preparation at Hyprland startup

Hyprland prepares the desktop assets before starting Hyprpaper.

Conceptually, startup performs:

```bash
~/dotfiles/scripts/prepare-desktop-assets.sh && hyprpaper
```

Therefore a normal login reconstructs missing or outdated normalized assets
before the wallpaper daemon starts.

The preparation script uses SHA-256 state files to avoid unnecessary image
conversion when the source files have not changed.

### Validation

Validate the source assets independently with:

```bash
./scripts/prepare-desktop-assets.sh --check
```

Run the complete desktop configuration validation with:

```bash
./scripts/check-desktop-config.sh
```

A valid configuration requires:

1. ImageMagick to be installed.
2. `prepare-desktop-assets.sh` to be executable.
3. Exactly one readable `wallpaper.*` source.
4. Exactly one readable `hyprlock.*` source.
5. Exactly one readable `profile.*` source.

If multiple readable files have the same logical basename, remove the obsolete
source rather than relying on filename or extension precedence.

### SDDM

The normalized files under:

```text
~/.cache/dotfiles/assets/
```

are user-session assets.

SDDM runs outside the normal user session and should not depend on this
user-specific cache. SDDM visual assets are therefore handled separately from
the Hyprpaper/Hyprlock asset pipeline.
