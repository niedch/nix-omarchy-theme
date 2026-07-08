# nix-omarchy-theme

Declarative multi-theme manager for NixOS + Hyprland. Instant runtime switching via symlink flip, plus NixOS specialisations for boot-time theme selection.

## Features

- **Multi-theme management** — define themes from Git repos containing a `colors.toml`
- **17 built-in app templates** — Alacritty, Btop, Chromium, Foot, Ghostty, Gum, Helix, Hyprland, Hyprlock, Hyprland preview picker, Keyboard RGB, Kitty, Mako, Obsidian, SwayOSD, Walker, Waybar
- **Template placeholders** — `{{ key }}` (hex), `{{ key_strip }}` (hex without `#`), `{{ key_rgb }}` (dec commas)
- **Per-app override** — theme repos can ship their own config files, which take precedence over built-in templates
- **Instant runtime switching** — `ts` command flips the active theme symlink; apps reload via hooks
- **NixOS specialisations** — each theme also gets a boot-time specialisation entry for bootloader selection
- **Wallpaper support** — themes can include a `backgrounds/` directory; `theme-wallpaper` lets you pick one
- **XDG symlinks** — symlink theme files into `~/.config/` via a mutable `current` symlink
- **Custom hooks** — executable scripts in `~/.config/theme-switcher/hooks/` run on every theme switch

## How it works

**Runtime switching**: The Home Manager module builds all themes as nix derivations. On activation, each theme is symlinked into `~/.local/share/themes/<name>` → its store path, and a mutable `current` symlink points to the `defaultTheme`. `xdg.configFile` entries use `mkOutOfStoreSymlink` to point into `~/.local/share/themes/current/`. The `ts` command flips the `current` symlink and runs hooks — instant, no rebuild.

**Boot-time selection**: The NixOS module generates one `specialisation` per theme. Each overrides `home-manager.users.<name>.omarchy-themes.defaultTheme`. Select one at boot or run `sudo /run/current-system/specialisation/<theme>/bin/switch-to-configuration switch`. Note: due to NixOS recursion guards, specialisations do not nest — switching via specialisation clears other specialisations. Use `ts` for repeated switching within a session.

## Installation

Add the flake as an input and import both modules:

```nix
{
  inputs.nix-omarchy-theme.url = "github:niedch/nix-omarchy-theme";

  outputs = { self, nixpkgs, home-manager, nix-omarchy-theme, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        home-manager.nixosModules.home-manager
        nix-omarchy-theme.nixosModules.default

        ({ inputs, ... }: {
          home-manager.users.myuser = { inputs, ... }: {
            imports = [ inputs.nix-omarchy-theme.homeManagerModules.default ];
          };
        })
      ];
    };
  };
}
```

## Usage

Define your themes in the home-manager config and configure the NixOS module:

```nix
# Home Manager module (home-manager.users.myuser)
{
  imports = [ inputs.nix-omarchy-theme.homeManagerModules.default ];

  omarchy-themes = {
    enable = true;
    defaultTheme = "kanso";

    selectorCommand = "walker --dmenu";

    themes = {
      catppuccin = {
        url = "https://github.com/basecamp/omarchy.git";
        rev = "abc123...";
        hash = "sha256-...";
        subpath = "themes/catppuccin";
      };

      kanso = {
        url = "https://github.com/user/my-theme.git";
        rev = "def456...";
        hash = "sha256-...";
        defaultBackground = "BG_Painting.jpg";
        extraBackgrounds = [{
          url = "https://example.com/bg.jpg";
          hash = "sha256-...";
          filename = "BG_Painting.jpg";
        }];
      };
    };

    symlinks = {
      "hypr/theme.lua".source = "hyprland.lua";
      "hypr/hyprlock-theme.conf".source = "hyprlock.conf";
      "waybar/colors.css".source = "waybar.css";
      "walker/themes/default/walker.css".source = "walker.css";
      "mako/config".source = "mako.ini";
      "btop/themes/btop.theme".source = "btop.theme";
      "gtk-3.0/settings.ini" = { source = "settings-3.0.ini"; recursive = false; };
      "gtk-4.0/settings.ini" = { source = "settings-4.0.ini"; recursive = false; };
      "gtk-3.0/gtk.css".source = "gtk.css";
      "gtk-4.0/gtk.css".source = "gtk.css";
    };
  };
}
```

### NixOS module

```nix
# NixOS module
{
  imports = [ inputs.nix-omarchy-theme.nixosModules.default ];
  omarchy-themes-nixos.user = "myuser";
}
```

Each theme (except `defaultTheme`) becomes a NixOS specialisation visible at `/run/current-system/specialisation/<theme>/` and in the bootloader menu.

## Switching themes

### `ts` — instant runtime switch

The module installs `ts` (aliased to `ts` in zsh). It lists all installed themes, flips the `current` symlink, and runs hooks to reload apps. Sub-second, no sudo, no rebuild:

```bash
ts
# → dmenu picker lists all themes
# → symlink flip + hooks (hyprctl reload, restart waybar/walker/mako, GTK update, etc.)
```

### Bootloader / specialisation switch

Each theme also appears as a NixOS specialisation. Select one at boot, or switch with:

```bash
sudo /run/current-system/specialisation/<theme>/bin/switch-to-configuration switch
```

This triggers a full NixOS activation (~1–3min). Note: NixOS does not support nesting specialisations — after switching this way, further specialisations are unavailable until next `nixos-rebuild switch`. Use `ts` for repeat switching within a session.

## Consumer-side app setup

Some applications need explicit configuration to point at the theme files rendered to `~/.local/share/themes/current/`. Below are the common setups.

### Ghostty

```nix
programs.ghostty.settings."config-file" =
  "?~/.local/share/themes/current/ghostty.conf";
```

### Obsidian

```nix
home.file."path/to/your-vault/.obsidian/snippets/obsidian.css" = {
  source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.local/share/themes/current/obsidian.css";
};
```

### Neovim (LazyVim)

```lua
local theme_file = vim.fn.expand("~/.local/share/themes/current/neovim.lua")
if vim.loop.fs_stat(theme_file) then
  vim.list_extend(plugins, dofile(theme_file))
end
```

### swaybg

```nix
systemd.user.services.swaybg.Service.ExecStart =
  "${pkgs.swaybg}/bin/swaybg -i %h/.local/share/themes/current-background -m fill";
```

The `current-background` symlink is updated automatically whenever a theme is switched.

### Chromium

```nix
xdg.configFile."chromium/Policies/managed/color.json".source =
  config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.local/share/themes/current/chromium-color.json";
```

### Walker

```nix
omarchy-themes.symlinks."walker/themes/default/walker.css".source = "walker.css";
```

Then write a `style.css` that imports it:

```css
@import "./walker.css";
```

### Waybar, Hyprland, Mako, Btop, GTK

These apps read files placed by `omarchy-themes.symlinks`. Once the symlink entries are defined, they pick up theme changes automatically on each NixOS activation.

## Provided commands

### `ts`

Lists installed themes, flips the `current` symlink, and runs hooks. Instant, no sudo, no rebuild.

### `theme-wallpaper`

Lists wallpapers from the active theme's `backgrounds/` directory and sets the selected one by updating `~/.local/share/themes/current-background`. Restarts swaybg if running.

## Custom templates

Override or extend the built-in templates:

```nix
omarchy-themes.templates."ghostty.conf" = ''
  background = {{ background }}
  foreground = {{ foreground }}
  palette = 0={{ color0 }}
'';
```

## Custom hooks

Hooks run after theme activation. `$1` is the theme name.

### Via Nix (`afterHooks`)

```nix
omarchy-themes.afterHooks = {
  "50_restart_polybar" = ''
    polybar "$1" &
  '';
};
```

Set `afterHooks = {}` to disable all built-in hooks.

### Manual

Place executable scripts in `~/.config/theme-switcher/hooks/theme-set.d/` — they run sorted alphabetically. `~/.config/theme-switcher/hooks/theme-set` runs after all `.d/*` scripts.

## Theme repository format

Each theme is a Git repository containing at minimum a `colors.toml`:

```toml
background = "#1e1e2e"
foreground = "#cdd6f4"
cursor = "#f5e0dc"
accent = "#cba6f7"
selection_background = "#585b70"
selection_foreground = "#cdd6f4"
color0 = "#45475a"
# ... color1 through color15
```

Optional files:

| File | Purpose |
|------|---------|
| `light.mode` | Empty marker — light theme; sets GTK to `Adwaita` + `prefer-light` |
| `gtk.theme` | GTK theme name (e.g. `"Tokyo-Night"`) |
| `icons.theme` | Icon theme name (e.g. `"Yaru-prussiangreen"`) |
| `backgrounds/` | Wallpaper images |
| Any template name | Overrides the built-in template for that app |

## Template placeholders

| Variant | Example | Output |
|---|---|---|
| `{{ background }}` | `#1e1e2e` | Full hex |
| `{{ background_strip }}` | `1e1e2e` | Hex without `#` |
| `{{ background_rgb }}` | `30,30,46` | Decimal RGB (comma-separated) |

Available color keys: `background`, `foreground`, `cursor`, `accent`, `selection_background`, `selection_foreground`, `color0`–`color15`.

## Built-in templates

| Template file | Application |
|---|---|
| `alacritty.toml` | Alacritty terminal |
| `btop.theme` | Btop system monitor |
| `chromium.theme` | Chromium browser |
| `chromium-color.json` | Chromium policy color |
| `foot.ini` | Foot terminal |
| `ghostty.conf` | Ghostty terminal |
| `gum.env.conf` | Charm Gum TUI |
| `helix.toml` | Helix editor |
| `hyprland.conf` | Hyprland border color |
| `hyprland-preview-share-picker.css` | Hyprland screenshot UI |
| `hyprlock.conf` | Hyprlock |
| `keyboard.rgb` | Keyboard backlight |
| `kitty.conf` | Kitty terminal |
| `mako.ini` | Mako notifications |
| `obsidian.css` | Obsidian |
| `swayosd.css` | SwayOSD |
| `walker.css` | Walker launcher |
| `waybar.css` | Waybar |

## Options reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the module |
| `defaultTheme` | str | `"default"` | Theme activated on rebuild |
| `selectorCommand` | str | wofi dmenu | Command that reads stdin and outputs selection |
| `themes` | attrset | `{}` | Theme definitions (url, rev, hash, subpath, backgrounds) |
| `templates` | attrset | built-in | Template overrides (`"name.tpl"` → content) |
| `afterHooks` | attrset | built-in | Hook script contents (key → shell script) |
| `symlinks` | attrset | `{}` | XDG config paths to symlink from the active theme |
| `activeTheme` | path | (read-only) | Store path of the active theme derivation |

## Development

```sh
nix develop
```

Provides `alejandra` (formatter) and `statix` (linter). Format with `nix fmt`.
