# GNU Stow layout

This repository uses GNU Stow to deploy user configuration files.

## Repository location

The repository is expected at:

    ~/dotfiles

## Stow packages

The Stow packages are stored under:

    ~/dotfiles/configs

Each package reproduces paths relative to the user's home directory.

For example:

    configs/hypr/.config/hypr/hyprland.conf

is deployed as:

    ~/.config/hypr/hyprland.conf

## Commands

Validate all packages:

    ./scripts/stow-preflight.sh

Deploy or update one package:

    ./scripts/stow-config.sh hypr

Remove links belonging to one package:

    ./scripts/unstow-config.sh hypr

## XDG user directories

The `xdg-user-dirs` Stow package manages:

    ~/.config/user-dirs.conf
    ~/.config/user-dirs.dirs

The directories themselves are not symbolic links. The installer must
create the physical directories required by `user-dirs.dirs`, currently:

    ~/Desktop
    ~/Downloads

The remaining XDG categories are redirected to `~/Downloads`.

`user-dirs.conf` disables automatic rewriting of this configuration.
Do not run `xdg-user-dirs-update` without first reviewing its effect on
the files managed by Stow.

## Machine-specific configuration

Monitor names, resolutions, refresh rates, GPU configuration and backlight
devices may differ between computers.

They must be configured separately for each machine.
