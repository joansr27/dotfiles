# Package Layout

This document summarizes how package manifests are organized. The complete
operational workflow is documented in `README.md`.

## Official packages

Official Arch Linux repository packages are stored under:

```text
packages/
├── common/
├── features/
├── hardware/
└── profiles/
```

### `common/`

Packages shared by all supported machines.

The files are grouped by responsibility:

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

### `features/`

Optional or purpose-specific package groups that may be reused by several
machine profiles.

Examples:

```text
remote-access.txt
science-development.txt
```

### `hardware/`

Drivers, microcode, graphics stacks, and utilities tied to a machine or
hardware family.

Current files:

```text
amd-laptop.txt
omen-intel-nvidia.txt
```

### `profiles/`

Each profile is a list of manifest paths relative to `packages/`.

Examples:

```text
amd-current.txt
omen.txt
```

Resolve a profile with:

```bash
./scripts/resolve-packages.sh omen
```

## AUR packages

AUR manifests are stored under:

```text
packages/aur/
├── common.txt
├── optional/
└── profiles/
```

### `common.txt`

AUR packages shared by supported machines.

### `optional/`

Optional AUR feature groups.

### `profiles/`

Each AUR profile lists manifest paths relative to `packages/aur/`.

Resolve an AUR profile with:

```bash
./scripts/resolve-aur-packages.sh omen
```

## Source-of-truth rule

Active package state must be represented only under `packages/`.

Historical inventories under `docs/` are records of previous system states and
are not read by the installer.

Do not create a new root-level monolithic `packages.txt`.

## Adding packages

Preferred command:

```bash
./scripts/add-package.sh \
    --source official \
    --package package-name \
    --manifest common/07-applications.txt
```

AUR example:

```bash
./scripts/add-package.sh \
    --source aur \
    --package package-name \
    --manifest common.txt
```

For a new feature manifest:

```bash
./scripts/add-package.sh \
    --source official \
    --package package-name \
    --manifest features/example.txt \
    --profiles amd-current,omen
```

The script validates package origin, prevents official/AUR duplication,
installs the package unless requested otherwise, updates manifests, sorts
entries, resolves affected profiles, and displays the Git diff.

It does not stage, commit, or push automatically.
