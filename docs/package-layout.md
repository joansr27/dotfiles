# Package Layout

This document summarizes how package manifests are organized. The complete
operational workflow is documented in `README.md`.

## Package source policy

All packages managed by this repository must be available from an enabled
official Arch Linux Pacman repository.

A compliant installation must satisfy:

```bash
pacman -Qm
```

with no output.

## Package manifests

```text
packages/
├── common/
├── features/
├── hardware/
└── profiles/
```

### `common/`

Packages shared by all supported machines.

Current manifests:

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

Optional or purpose-specific package groups reused by one or more machine
profiles.

Current manifests include:

```text
remote-access.txt
science-development.txt
```

`remote-access.txt` currently contains the official packages `tailscale` and
`wayvnc`.

Neither package is configured for remote desktop by this repository. External
KVM hardware such as PiKVM is the preferred future remote-access architecture.

### `hardware/`

Drivers, microcode, graphics stacks, and utilities tied to a particular
machine or hardware family.

Current manifests:

```text
amd-laptop.txt
omen-intel-nvidia.txt
```

### `profiles/`

Each profile lists manifest paths relative to `packages/`.

Current profiles:

```text
amd-current.txt
omen.txt
```

Resolve a profile with:

```bash
./scripts/resolve-packages.sh omen
```

Validate it with:

```bash
./scripts/validate-packages.sh omen
```

## Sorting invariant

Every `.txt` file under `packages/` must remain alphabetically sorted using the
C locale.

The package helper automatically sorts package and profile manifests that it
modifies.

Manual validation:

```bash
find packages -type f -name '*.txt' -print0 |
while IFS= read -r -d '' file; do
    LC_ALL=C sort -c "$file" ||
        printf '[ERROR] Not sorted: %s\n' "$file"
done
```

## Adding packages

Add an official package with:

```bash
./scripts/add-package.sh \
    --package package-name \
    --manifest common/07-applications.txt
```

For a new feature shared by multiple profiles:

```bash
./scripts/add-package.sh \
    --package package-name \
    --manifest features/example.txt \
    --profiles amd-current,omen
```

The helper:

1. validates the package with Pacman;
2. rejects packages absent from enabled official repositories;
3. prevents duplicate placement across package manifests;
4. installs the package unless `--no-install` is used;
5. updates the requested manifest;
6. updates requested profile files;
7. sorts modified manifests;
8. resolves affected profiles;
9. displays the Git diff.

It never stages, commits, or pushes automatically.

## Source-of-truth rule

Active package state is represented only under `packages/`.

Do not create a root-level monolithic `packages.txt`.

Do not add foreign-package or alternate-package-manager manifests to the active
package tree.
