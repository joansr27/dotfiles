# GNU Stow layout

The complete operational documentation is available in the repository
`README.md`.

The Stow root is:

    ~/dotfiles/configs

The deployment target is:

    $HOME

Validate all packages:

    ./scripts/stow-preflight.sh

Deploy one package:

    ./scripts/stow-config.sh <package>

Remove one package:

    ./scripts/unstow-config.sh <package>

Machine selection:

    ./scripts/select-machine.sh amd-current
    ./scripts/select-machine.sh omen

The local selector:

    configs/hypr/.config/hypr/machine.lua

is intentionally ignored by Git.
