# nix-omarchy-theme

Declarative multi-theme manager for NixOS + Hyprland, built as a Home Manager module.

Define color themes from Git repositories, render 17 application templates, switch themes at runtime, and have your entire desktop follow — terminals, bars, editors, notifications, lockscreens, and more.

## Demo

<video src="https://github.com/niedch/nix-omarchy-theme/raw/master/assets/theme-switcher.mp4" controls width="100%"></video>


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

Hooks run after a theme has been switched. Within a hook, `$1` gives you the selected theme name.

### Via Nix (`afterHooks`)

The built-in hooks are defined as defaults but can be overridden or extended using the `afterHooks` option:

```nix
{
  omarchy-themes.afterHooks = {
    # Override a built-in hook
    "0_reload_defaults" = ''
      hyprctl reload 2>/dev/null || true
    '';
    # Add your own hooks — prefix with a number to control ordering, use $1 for the theme name
    "50_restart_polybar" = ''
      polybar "$1" &
    '';
  };
}
```

Set `afterHooks = {}` to disable all built-in hooks entirely.

### Manual

Place executable scripts in:

- `~/.config/theme-switcher/hooks/theme-set.d/` — each script runs with the theme name as `$1`, sorted alphabetically; use `$1` inside your script to access it
- `~/.config/theme-switcher/hooks/theme-set` — runs after all scripts in `theme-set.d/`

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

## Consumer-side app setup

Some applications need explicit configuration to point at the theme files rendered to `~/.local/share/themes/current/`. Below are the common setups.

<details>
<summary><b>Ghostty</b> — load theme config at startup</summary>

Point Ghostty's `config-file` at the theme's rendered `ghostty.conf`:

```nix
programs.ghostty = {
  enable = true;
  settings = {
    "config-file" = "?~/.local/share/themes/current/ghostty.conf";
  };
};
```

The `?` prefix means "load if the file exists, silently skip otherwise."
</details>

<details>
<summary><b>Neovim</b> — load theme Lua plugin specs at startup</summary>

If your theme repo ships a `neovim.lua` file, load it from your lazy/plugin setup:

```lua
local theme_file = vim.fn.expand("~/.local/share/themes/current/neovim.lua")
if vim.loop.fs_stat(theme_file) then
  vim.list_extend(plugins, dofile(theme_file))
end
```

Theme repos can override the `neovim.lua` template (or provide their own) to inject color scheme commands, highlight overrides, or additional plugin specs at runtime.
</details>

<details>
<summary><b>Obsidian</b> — symlink theme CSS into your vault</summary>

Symlink the rendered `obsidian.css` into your vault's snippets folder:

```nix
home.file."path/to/your-vault/.obsidian/snippets/obsidian.css" = {
  source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.local/share/themes/current/obsidian.css";
};
```

Then enable the snippet in Obsidian's **Settings → Appearance → CSS snippets**.

If you also want **live reload** when switching themes (via `theme-switcher`), enable the built-in CLI in Obsidian (**Settings → General → Command line interface**) and follow the prompt to register it. The built-in `0_reload_defaults` hook will then send a reload command to Obsidian on every theme switch. You can disable or override this via the `afterHooks` option.
</details>

<details>
<summary><b>swaybg</b> — point wallpaper service at theme background</summary>

Point the swaybg systemd service at the `current-background` symlink that nix-omarchy-theme maintains:

```nix
systemd.user.services.swaybg = {
  Service = {
    ExecStart = "${pkgs.swaybg}/bin/swaybg -i %h/.local/share/themes/current-background -m fill";
  };
};
```

The `current-background` symlink is updated automatically whenever a theme is switched.
</details>

<details>
<summary><b>Walker</b> — load theme colors via <code>style.css</code></summary>

Symlink the rendered `walker.css` into Walker's theme directory, then write a `style.css` that imports it so the theme's color variables (`@text`, `@base`, `@border`, …) are available to your custom rules:

```nix
omarchy-themes.symlinks."walker/themes/default/walker.css".source = "walker.css";
```

`style.css` (placed at `~/.config/walker/themes/default/style.css`) begins with:

```css
@import "./walker.css";
```

and is selected in `config.toml` via `theme = "default"`. The accompanying `layout.xml` defines the GTK widget structure (window, search box, list, preview).

Reference files from a working setup:

- [style.css](https://github.com/niedch/nixos-dotfiles/blob/master/home/walker/style.css)
- [layout.xml](https://github.com/niedch/nixos-dotfiles/blob/master/home/walker/layout.xml)

</details>

<details>
<summary><b>Chromium & Chrome-based browsers</b> — apply theme color via a policy hook</summary>

The module renders a `chromium-color.json` (`{"BrowserThemeColor": "{{ background }}"}`) into `~/.local/share/themes/current/`. The `BrowserThemeColor` managed policy sets the browser's toolbar/chrome accent color.

Chrome-based browsers only re-read policies when the policy file's **content** changes on disk — a symlink swap (relinking `current/` on theme switch) doesn't produce a content-change event, so the new color is never picked up. The built-in `02_apply_chromium_color` hook solves this by **copying** the json into the managed-policy directory on every switch, which the browser detects as a real change.

The built-in hook covers plain Chromium. To extend it to additional browsers, override the hook via `afterHooks`:

```nix
omarchy-themes.afterHooks."02_apply_chromium_color" = ''
  CURRENT="''${CURRENT:-$HOME/.local/share/themes/current}"
  for policy_dir in \
    "$HOME/.config/chromium/policies/managed" \
    "$HOME/.config/google-chrome/policies/managed" \
    "$HOME/.config/BraveSoftware/Brave-Browser/policies/managed" \
    "$HOME/.config/microsoft-edge/policies/managed" \
    "$HOME/.config/vivaldi/policies/managed"; do
    mkdir -p "$policy_dir"
    cp "$CURRENT/chromium-color.json" "$policy_dir/color.json"
  done
'';
```

Common Linux policy directories:

| Browser | Policy directory |
|---|---|
| Chromium | `~/.config/chromium/policies/managed/` |
| Google Chrome | `~/.config/google-chrome/policies/managed/` |
| Brave | `~/.config/BraveSoftware/Brave-Browser/policies/managed/` |
| Microsoft Edge | `~/.config/microsoft-edge/policies/managed/` |
| Vivaldi | `~/.config/vivaldi/policies/managed/` |

The new color takes effect on next browser launch.

</details>

## Development

```sh
nix develop
```

Provides `alejandra` (formatter) and `statix` (linter). The whole repo is formatted with `nix fmt`.
