# Future Roadmap

This document is a personal planning reference for future development of the Arch Linux / Hyprland workstation configuration.

The current repository state should be treated as the stable baseline. Future work can be developed incrementally from this point, with each major change validated before it replaces the current working configuration.

---

## Current baseline

- Stable Arch Linux + Windows dual boot.
- Reproducible dotfiles repository.
- Hyprland working environment.
- Machine-specific configuration structure.
- Explicit package manifests.
- Remote-access workflow with Tailscale + Sunshine.
- Current visual environment considered functional but temporary.

---

## 1. GRUB selector / boot UI

**Goal:** improve the boot experience without compromising dual-boot reliability.

Potential work:

- Design a clearer visual GRUB interface.
- Build an Arch / Windows selector.
- Improve typography, spacing, icons, and overall appearance.
- Keep fallback and recovery boot entries available.
- Preserve compatibility with the existing Windows EFI setup.
- Preserve BitLocker reliability.
- Test behavior after kernel, GRUB, Windows, firmware, and boot-order changes.

**Priority:** medium.  
**Risk:** moderate, because bootloader changes affect both operating systems.

---

## 2. GPU and power characterization

**Goal:** characterize the HP OMEN hardware before building UI controls around performance profiles.

### Characterization

Measure and compare:

- CPU and GPU clocks.
- NVIDIA power behavior and power limits.
- CPU/GPU temperatures.
- Fan behavior.
- System power profiles.
- AC versus battery behavior.
- FPS and frame times.
- GPU and CPU utilization.
- VRAM usage.
- Thermal throttling behavior.
- Performance consistency under sustained loads.

### Power profiles

Investigate practical profiles such as:

- Performance.
- Balanced.
- Power saving.
- Gaming-oriented profile.
- Quiet / low-power profile, if useful.

The behavior of each profile should be understood before exposing it through the desktop UI.

### Waybar integration

Potential additions:

- Current power-profile indicator.
- Interactive power-profile selector.
- GPU utilization.
- GPU temperature.
- GPU power draw.
- CPU temperature.
- FPS indicator.
- Frame-time indicator, if practical.
- VRAM usage.
- Optional gaming/performance status module.

**Priority:** high.  
**Risk:** low to moderate if characterization is separated from profile-changing logic.

---

## 3. Hyprland visual redesign

**Goal:** replace the current temporary working environment with a coherent visual system.

Potential areas:

- Global color palette.
- Typography.
- Window borders.
- Gaps and spacing.
- Animations.
- Waybar.
- Wofi.
- Hyprlock.
- Kitty.
- Notification system.
- Wallpapers and active visual assets.
- Workspace indicators.
- System-monitoring modules.
- GPU and power controls.
- Consistent iconography.
- Light/dark or alternate themes, if desirable.

The redesign should be treated as one coordinated theme rather than a collection of unrelated component changes.

**Priority:** medium to high.  
**Risk:** low, provided the current configuration remains available as a rollback reference.

---

## 4. Lua migration

**Goal:** migrate the Hyprland configuration architecture from the current configuration format to Lua when the ecosystem and available tooling are mature enough.

This is expected to be a large architectural project and should not be treated as a simple syntax translation.

### Research phase

Before changing the current setup:

- Study the current Lua configuration model.
- Identify the supported configuration surface.
- Understand imports, monitor configuration, keybindings, environment variables, autostart, window rules, workspace rules, input configuration, animations, decorations, machine-specific configuration, and runtime reload behavior.
- Identify limitations or differences compared with the current configuration format.
- Collect reliable reference implementations.

### Architecture phase

Define how Lua should represent:

- Common configuration.
- Machine-specific profiles.
- Reusable helpers.
- Constants.
- Theme data.
- Monitor rules.
- Application rules.
- Keybindings.
- Startup behavior.

Avoid reproducing the current file structure mechanically if Lua enables a cleaner architecture.

### Migration phase

Migrate incrementally, for example:

1. Environment variables.
2. General settings.
3. Input.
4. Monitor configuration.
5. Machine-specific settings.
6. Keybindings.
7. Window rules.
8. Workspace rules.
9. Autostart.
10. Decorations and animations.
11. Remaining modules.

After every stage:

- Reload Hyprland.
- Check configuration errors.
- Compare behavior against the current stable configuration.
- Keep rollback possible.

### Completion criteria

The legacy configuration should only be retired when:

- Feature parity is confirmed.
- Both machine profiles work.
- Monitor behavior is correct.
- Startup behavior is correct.
- Keybindings are preserved.
- Application rules behave correctly.
- No undocumented manual state is required.
- The new Lua structure is understandable and maintainable.

**Priority:** long-term.  
**Risk:** high relative to the other roadmap items because it changes the configuration architecture itself.

---

## Suggested order

```text
CURRENT STABLE BASELINE
│
├──► 1. GRUB SELECTOR / BOOT UI
│       ├─ Visual GRUB redesign
│       ├─ Arch / Windows selector
│       ├─ Safe fallback entries
│       └─ Preserve BitLocker + dual-boot reliability
│
├──► 2. GPU + POWER CHARACTERIZATION
│       ├─ CPU/GPU monitoring
│       ├─ NVIDIA power behavior
│       ├─ Performance / balanced / power-saving profiles
│       ├─ Temperatures, clocks, and fan behavior
│       ├─ FPS + frame-time monitoring
│       └─ Waybar profile selector + indicators
│
├──► 3. HYPRLAND VISUAL REDESIGN
│       ├─ New global theme
│       ├─ Waybar redesign
│       ├─ Wofi
│       ├─ Hyprlock
│       ├─ Kitty
│       ├─ Notifications
│       ├─ Wallpapers / visual assets
│       └─ Integrate GPU/power controls into the final UI
│
└──► 4. LUA MIGRATION
        ├─ Research the current Lua configuration model
        ├─ Define an equivalent repository architecture
        ├─ Preserve machine-specific profiles
        ├─ Migrate subsystem by subsystem
        ├─ Compare behavior with the current stable baseline
        ├─ Validate after every migration stage
        └─ Retire the legacy configuration only when parity is proven
```

---

## General implementation principles

For future work:

- Keep `main` deployable.
- Prefer feature branches for substantial changes.
- Create a Timeshift snapshot before high-risk system changes.
- Preserve the existing working configuration until replacement behavior is verified.
- Avoid coupling unrelated refactors.
- Characterize hardware behavior before building UI abstractions around it.
- Keep machine-specific logic isolated.
- Keep secrets, credentials, and private runtime state outside Git.
- Update documentation when behavior or repository architecture changes.
- Validate scripts and configuration before merging.

The objective is not to turn the repository into a distribution project. It is a durable, reproducible record of the workstation and a structured basis for future experimentation.
