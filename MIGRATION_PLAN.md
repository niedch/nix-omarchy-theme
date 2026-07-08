# Migration Plan: Out-of-Store Symlinking → NixOS Specialisations

## Decision context (locked in)

- **Goal**: fully adopt NixOS `specialisation` for themes; accept ~1–3min rebuild per
  switch; lose instant `ts` symlink swap.
- **Layer**: NixOS `specialisation` (stable, non-experimental). Each theme = a NixOS
  specialisation that overrides `home-manager.users.nic.omarchy-themes.defaultTheme`.
- **Activation**: `sudo /run/current-system/specialisation/<theme>/bin/switch-to-configuration switch`
- **Switch UX**: a `ts` wrapper that runs the above via sudo.

---

## Section A — Architecture

**One NixOS config + N NixOS specialisations** (one per non-default theme).
The `nix-omarchy-theme` flake exposes:

- `homeManagerModules.default` (existing, refactored) — the pure-store-symlink +
  `activeTheme` + hooks HM module.
- **NEW `nixosModules.default`** — generates one NixOS `specialisation.<theme>` per
  theme by reading `config.home-manager.users.<user>.omarchy-themes.themes` and
  overriding `home-manager.users.<user>.omarchy-themes.defaultTheme` per
  specialisation.

Each specialisation re-evaluates the whole system with a different `activeTheme`
derivation; the HM module places that theme's rendered files as **pure nix store
symlinks** via `xdg.configFile.<target>.source = "${activeTheme}/<file>"`.

No `mkOutOfStoreSymlink`, no `~/.local/share/themes/current` farm, no
activation-script symlink flip.

---

## Section B — Changes in `nix-omarchy-theme`

### B1. `flake.nix`

Add `nixosModules.default` output:

```nix
nixosModules.default = import ./modules/nixos/specialisations.nix;
```

### B2. NEW `modules/nixos/specialisations.nix`

```nix
{ lib, config, ... }: let
  user = config.omarchy-themes-nixos.user;  # new NixOS option
  themes = config.home-manager.users.${user}.omarchy-themes.themes;
  defaultTheme = config.home-manager.users.${user}.omarchy-themes.defaultTheme;
in {
  options.omarchy-themes-nixos.user = lib.mkOption {
    type = lib.types.str;
    default = "nic";
    description = "Home Manager user for theme specialisations";
  };
  config.specialisation = lib.mapAttrs (name: _: {
    configuration.home-manager.users.${user}.omarchy-themes.defaultTheme =
      lib.mkForce name;
  }) (lib.removeAttrs themes [ defaultTheme ]);
}
```

### B3. `modules/omarchy-themes/runtime-switcher.nix` → `theme-module.nix`

1.  Compute `activeTheme = buildTheme { name = cfg.defaultTheme; theme =
    cfg.themes.${cfg.defaultTheme}; ... }`.
2.  Add read-only option `omarchy-themes.activeTheme` (derivation / store path)
    exposed for consumers.
3.  Replace `mkOutOfStoreSymlink` `xdg.configFile` entries with pure store symlinks:
    ```nix
    xdg.configFile."<target>" = {
      source = "${activeTheme}/${symlink.source}";
      recursive = symlink.recursive;
    };
    ```
4.  **Remove** `home.activation.setupThemes` (the symlink-farm activation).
    Replace with a smaller activation script that runs the `theme-set.d` hooks
    on every HM activation (so they fire on specialisation `switch` too). Hooks
    read `${activeTheme}` instead of `~/.local/share/themes/current`.
5.  **Remove** old `theme-switcher`. Replace with a new `ts` `writeShellScriptBin`
    that lists NixOS specialisations at `/run/current-system/specialisation/` and
    activates the chosen one:
    ```bash
    set -euo pipefail
    SPECS=$(ls /run/current-system/specialisation/ 2>/dev/null)
    CHOSEN=$(printf '%s\n' "$SPECS" | walker --dmenu)
    [ -z "$CHOSEN" ] && exit 0
    exec sudo /run/current-system/specialisation/$CHOSEN/bin/switch-to-configuration switch
    ```
6.  Keep `theme-wallpaper` — it maintains a writable
    `~/.local/share/themes/current-background` symlink pointing to the active
    theme's store `backgrounds/<file>`. Selection resets to the theme's
    `defaultBackground` on each specialisation switch.
7.  Keep package installs (`dconf`, `glib`, `gsettings-desktop-schemas`, `gtk4`,
    `libadwaita`, `adwaita-icon-theme`, `yaru-theme`, `libnotify`).
8.  **Drop** `02_apply_chromium_color` from default hooks — replaced by static
    `xdg.configFile` in the consumer (Section C).

### B4. `modules/omarchy-themes/hooks/default.nix`

- `01_apply_gtk`: read `gtk.theme`/`icons.theme` from `${activeTheme}` (the
  module passes the path via env `CURRENT` when running hooks).
- **Drop** `02_apply_chromium_color`.
- `03_reload_defaults`, `90_restart_nautilus`, `95_notify`: unchanged.

### B5. `README.md`

Rewrite to describe:
- NixOS specialisations as the switching mechanism.
- `ts` (sudo-based, ~1–3min rebuild).
- `${config.omarchy-themes.activeTheme}` reference pattern for consumers.
- `theme-wallpaper` semantics (writable selection, resets on switch).

---

## Section C — Changes in `nixos-dotfiles`

### C1. `flake.nix`

No structural change. `nix-omarchy-theme` input is already passed via
`extraSpecialArgs`. The new `nixosModules.default` is imported in
`modules/desktop`. The `mkSystem` helper already includes
`./modules/desktop` for desktop/laptop hosts.

### C2. NEW `modules/desktop/themes.nix`

```nix
{ inputs, ... }: {
  imports = [ inputs.nix-omarchy-theme.nixosModules.default ];
  omarchy-themes-nixos.user = "nic";
}
```

Add to `modules/desktop/default.nix` imports:

```nix
imports = [
  ./themes.nix
  # ... existing imports
];
```

### C3. `home/themes/default.nix`

- Keep: `themes`, `defaultTheme`, `templates`, `afterHooks`, `symlinks`.
- **Remove**: `selectorCommand = "walker --dmenu"` (the new `ts` hardcodes walker).
- Keep: `04_spicetify_apply` afterHook.
- **Add** static chromium policy placement:
  ```nix
  xdg.configFile."chromium/Policies/managed/color.json".source =
    "${config.omarchy-themes.activeTheme}/chromium-color.json";
  ```

### C4. `home/ghostty/default.nix`

Add `config` to the function arguments and replace the theme config-file path:

```nix
{ pkgs, config, ... }: {
  programs.ghostty.settings."config-file" =
    "?${config.omarchy-themes.activeTheme}/ghostty.conf";
}
```

### C5. `home/obsidian/default.nix`

Replace `mkOutOfStoreSymlink` with pure store symlink:

```nix
{ config, pkgs, ... }: {
  home.file."Projects/obsidian-vault/.obsidian/snippets/obsidian.css".source =
    "${config.omarchy-themes.activeTheme}/obsidian.css";
}
```

### C6. `home/nvim/default.nix` + `lazy.lua`

In `nvim/default.nix`, add a generated Lua shim:

```nix
{ config, ... }: {
  xdg.configFile."nvim/lua/nic/theme.lua".text = ''
    return (function()
      local ok, t = pcall(dofile, "${config.omarchy-themes.activeTheme}/neovim.lua")
      return ok and t or {}
    end)()
  '';
}
```

In `lazy.lua` (`home/nvim/nvim-config/lua/nic/lazy.lua`), replace lines 21–24:

```lua
-- Replace:
-- local theme_file = vim.fn.expand("~/.local/share/themes/current/neovim.lua")
-- if vim.loop.fs_stat(theme_file) then
--   vim.list_extend(plugins, dofile(theme_file))
-- end

-- With:
local theme_plugins = require("nic.theme")
vim.list_extend(plugins, theme_plugins)
```

### C7. `home/hyprland/services.nix` (swaybg)

Unchanged — keeps `-i %h/.local/share/themes/current-background` since we keep
the writable background symlink (per user's D3 decision).

### C8. No source changes needed

- `home/walker/default.nix`, `home/waybar/default.nix` — `@import` resolution
  unaffected (store vs out-of-store symlink both resolve).
- `home/hyprland/default.nix` + `hyprland.lua` — `dofile(~/.config/hypr/theme.lua)`
  still reads the HM-managed store symlink.
- `desktop.nix` `programs.btop.settings.color_theme = "btop"` — unchanged.

---

## Section D — Behavioural changes summary

|                      | Before                                    | After                                                    |
| -------------------- | ----------------------------------------- | -------------------------------------------------------- |
| Switch speed         | sub-second                                | ~1–3min (NixOS rebuild)                                  |
| Switch command       | `ts` (symlink flip)                       | `ts` → `sudo ... switch-to-configuration switch`          |
| Needs root           | no                                        | **yes (sudo)**                                           |
| Bootloader entries   | none                                      | one per theme                                            |
| `~/.local/share/themes/current` | mutable symlink             | **gone**                                                 |
| Apps reference       | `~/.local/share/themes/current/...`       | `${config.omarchy-themes.activeTheme}/...` (store path)   |
| Wallpaper picker     | runtime swap                              | kept (writable symlink, resets on switch)                 |
| Chromium color       | runtime `cp` hook                         | static `xdg.configFile` policy                           |

---

## Section E — Implementation order

1.  `nix-omarchy-theme`: refactor `runtime-switcher.nix` → `theme-module.nix`
    (pure store symlinks, `activeTheme`, remove symlink farm, new `ts`,
    keep `theme-wallpaper`).
2.  `nix-omarchy-theme`: add `modules/nixos/specialisations.nix` +
    `nixosModules.default` in `flake.nix`.
3.  `nix-omarchy-theme`: update `hooks/default.nix` (drop 02, reroute 01 to
    `${activeTheme}`).
4.  `nix-omarchy-theme`: rewrite `README.md`.
5.  `nixos-dotfiles`: add `modules/desktop/themes.nix` importing the NixOS
    module; add to imports.
6.  `home/themes/default.nix`: drop `selectorCommand`, add static chromium
    policy `xdg.configFile`.
7.  `home/ghostty/default.nix`: `${config.omarchy-themes.activeTheme}/ghostty.conf`.
8.  `home/obsidian/default.nix`: pure store symlink.
9.  `home/nvim/default.nix` + `lazy.lua`: generated `theme.lua` shim.
10. Verify `home/hyprland/services.nix`, walker, waybar, hypr, btop need no change.
11. Build: `nix build .#nixosConfigurations.desktop.config.system.build.toplevel`
    and confirm `/run/current-system/specialisation/` lists themes.
12. Lint/format: `nix fmt` in `nix-omarchy-theme` (alejandra).

---

## Open risks

- **Bootloader pollution**: every theme gets a GRUB/systemd-boot entry.
  Mitigate by naming conventions (`theme-kanso`, `theme-gruvbox`…) or accept it.
- **`sudo` in `ts`**: may need `NOPASSWD` for the specific switch path or
  accept password prompts.
- **Rebuild performance**: NixOS specialisations re-evaluate the whole system
  per theme. First build is slow; subsequent cached rebuilds are faster but
  still heavier than HM-only.
- **`mkForce` override**: ensuring `defaultTheme` override wins cleanly in
  specialisations — verified mental model but needs build-time confirmation.
