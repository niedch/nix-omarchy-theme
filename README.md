# nix-omarchy-theme

Declarative multi-theme manager for NixOS + Hyprland, built as a Home Manager module.

Define color themes from Git repositories, render 17 application templates, switch themes at runtime, and have your entire desktop follow — terminals, bars, editors, notifications, lockscreens, and more.

## Features

- **Multi-theme management** — define any number of themes from Git repos containing a `colors.toml`
- **17 built-in app templates** — Alacritty, Btop, Chromium, Foot, Ghostty, Gum, Helix, Hyprland, Hyprlock, Hyprland preview picker, Keyboard RGB, Kitty, Mako, Obsidian, SwayOSD, Walker, Waybar
- **Template placeholders** — `{{ key }}` (hex), `{{ key_strip }}` (hex without `#`), `{{ key_rgb }}` (dec commas)
- **Per-app override** — theme repos can ship their own config files, which take precedence over built-in templates
- **Runtime switching** — `theme-switcher` command to select and apply a theme interactively
- **Wallpaper support** — themes can include a `backgrounds/` directory; `theme-wallpaper` lets you pick one
- **XDG symlinks** — symlink theme subdirectories (e.g. `hypr/`, `waybar/`) into `~/.config/`
- **Custom hooks** — executable scripts in `~/.config/theme-switcher/hooks/` run on every theme switch

## Installation

Add the flake as an input to your `flake.nix`:

```nix
{
  inputs.omarchy-theme.url = "github:omarchis/nix-omarchy-theme";

  outputs = { self, nixpkgs, home-manager, omarchy-theme, ... }: {
    homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        omarchy-theme.homeManagerModules.default
        # ... your config
      ];
    };
  };
}
```

## Usage

Enable the module and define your themes:

```nix
{
  omarchy-themes = {
    enable = true;
    defaultTheme = "catppuccin";

    themes.catppuccin = {
      url = "https://github.com/omarchis/catppuccin-omarchy";
      ref = "main";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      subpath = ".";
    };

    themes.gruvbox = {
      url = "https://github.com/omarchis/gruvbox-omarchy";
      ref = "main";
      hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    };

    # Symlink theme subdirectories into ~/.config/
    symlinks = {
      hypr = {};
      waybar = {};
      wallpapers = { source = "wallpapers"; };
    };
  };
}
```

### Theme selector

By default themes are selected with `wofi`. Set a different command:

```nix
{
  omarchy-themes.selectorCommand = "${pkgs.fzf}/bin/fzf --prompt=\"Select Theme \"";
}
```

### Custom templates

Override or extend the built-in templates:

```nix
{
  omarchy-themes.templates = {
    "ghostty.conf" = ''
      background = {{ background }}
      foreground = {{ foreground }}
      palette = 0={{ color0 }}
    '';
  };
}
```

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
color1 = "#f38ba8"
color2 = "#a6e3a1"
color3 = "#f9e2af"
color4 = "#89b4fa"
color5 = "#cba6f7"
color6 = "#94e2d5"
color7 = "#bac2de"
color8 = "#585b70"
color9 = "#f38ba8"
color10 = "#a6e3a1"
color11 = "#f9e2af"
color12 = "#89b4fa"
color13 = "#cba6f7"
color14 = "#94e2d5"
color15 = "#bac2de"
```

Optional files in the theme repo:

| File | Purpose |
|---|---|---|
| `light.mode` | Empty marker file — treat as light theme; sets GTK theme to `Adwaita` + `prefer-light` |
| `gtk.theme` | Override the GTK theme name (e.g. `"Tokyo-Night"`); takes highest priority over `light.mode` |
| `icons.theme` | Icon theme name (e.g. `"Yaru-prussiangreen"`); feeds into GTK's `icon-theme` setting |
| `backgrounds/` | Wallpaper images (any format) |
| Any template name | Overrides the built-in template for that app (e.g. `waybar.css`, `hyprland.conf`) |

## Template placeholders

Placeholder syntax in templates:

| Variant | Example | Output |
|---|---|---|
| `{{ background }}` | `#1e1e2e` | Full hex |
| `{{ background_strip }}` | `1e1e2e` | Hex without `#` |
| `{{ background_rgb }}` | `30,30,46` | Decimal RGB (comma-separated) |

Available color keys: `background`, `foreground`, `cursor`, `accent`, `selection_background`, `selection_foreground`, `color0`–`color15`.

## Provided commands

### `theme-switcher` (alias `ts` with zsh)

Lists all defined themes, applies the selected one: switches wallpaper, reloads Hyprland, restarts Waybar/Mako/Ghostty/Btop, updates GTK theme and icon theme via gsettings, and runs custom hooks.

### `theme-wallpaper`

Lists wallpapers from the current theme's `backgrounds/` directory and sets the selected one via swaybg.

## Custom hooks

Place executable scripts in:

- `~/.config/theme-switcher/hooks/theme-set.d/` — all scripts run with the theme name as argument
- `~/.config/theme-switcher/hooks/theme-set` — single script run with the theme name

## Built-in templates

| Template file | Application |
|---|---|
| `alacritty.toml` | Alacritty terminal |
| `btop.theme` | Btop system monitor |
| `chromium.theme` | Chromium browser |
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
| `obsidian.css` | Obsidian.md |
| `swayosd.css` | SwayOSD |
| `walker.css` | Walker launcher |
| `waybar.css` | Waybar |

## Development

```sh
nix develop
```

Provides `alejandra` (formatter) and `statix` (linter). The whole repo is formatted with `nix fmt`.
