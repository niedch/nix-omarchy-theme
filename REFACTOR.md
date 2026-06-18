# Refactoring Summary: Extract Reusable Shell Snippets

## Motivation

The original `default.nix` (247 lines) contained three duplicated shell script blocks
that appeared nearly identically in both the `setupThemes` activation script and the
`theme-switcher` runtime script. This made maintenance error-prone — any change to
GTK config, Chromium policy color, or background selection had to be updated in two
places.

## What Changed

### New file: `modules/omarchy-themes/scripts.nix`

A module that takes `{pkgs}` and exports reusable shell snippet strings
(conventional Nix `''...''` multi-line strings). Snippets use `$CURRENT` and
`$CURRENT_BG` as interface variables that callers set before use.

| Function | Purpose | Used by |
|---|---|---|---|
| `applyGtkConfig` | Read `gtk.theme` / `light.mode`, apply gsettings | activation + theme-switcher |
| `applyChromiumColor` | Read `chromium.theme`, convert RGB → hex, write `color.json` to all browser policy dirs | activation + theme-switcher |
| `selectBackground {preserveCurrentBg}` | Read `default-background`, link to `$CURRENT_BG`; when `true`, preserve previous bg if still present in new theme | activation (`false`) + theme-switcher (`true`) |
| `exportGsettingsSchemas` | `export GSETTINGS_SCHEMA_DIR=...` — contains the resolved Nix store path | activation + theme-switcher |

### Edited: `modules/omarchy-themes/default.nix`

**Before:** 247 lines, 3 duplicated blocks totalling ~110 lines of repeated shell code.

**After:** 146 lines (41% reduction). Both call sites now reference the shared snippets
via `${scripts.*}` interpolation.

Key differences from original:

- **Activation script** now sets `CURRENT`/`CURRENT_BG` shell variables at the top
  (matching the convention used by `theme-switcher`), instead of referencing
  `$THEMES_DIR/current` directly in the background block.
- **`GSETTINGS_SCHEMA_DIR`** is now exported in the activation script (was a
  non-exported local variable, which meant `gsettings` subprocess wouldn't see it).
  The theme-switcher already exported it correctly.
- **theme-wallpaper** and **build-theme.nix** are untouched — their overlap with the
  extracted snippets is minimal.

## Before/After Line Counts

| Location | Before | After | Saved |
|---|---|---|---|
| `default.nix` total | 247 | 146 | 101 |
| activation script body | 76 | 29 | 47 |
| theme-switcher script body | 102 | 47 | 55 |
| `scripts.nix` | — | 82 | (new) |

### Post-refactoring fix: re-added GTK config symlinks to `applyGtkConfig`

The `ln -sfn` symlinks for `~/.config/gtk-{3,4}.0/settings.ini` were originally removed
from `applyGtkConfig` because the `xdg.configFile` mechanism was thought to handle it.
However, the build step generates `settings-3.0.ini`/`settings-4.0.ini` (not `settings.ini`),
and there is no default `gtk-3.0`/`gtk-4.0` symlink entry. Even if a user added one, the
file name mismatch would prevent GTK apps from finding it. The symlinks were restored in
`scripts.nix:18-20` so that `~/.config/gtk-3.0/settings.ini` → `${currentLink}/settings-3.0.ini`
(and same for 4.0), ensuring GTK3/GTK4 apps (including Nautilus) pick up the correct theme.

## Files Unchanged

- `modules/omarchy-themes/options.nix`
- `modules/omarchy-themes/build-theme.nix`

## Verification

- `nix flake check` — passes
- `nix-instantiate --parse` — syntax valid
- Each snippet function was evaluated in isolation to confirm correct escaping
