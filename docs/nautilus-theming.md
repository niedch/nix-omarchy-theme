# Nautilus Theming Guide

How the GNOME Files (Nautilus) file manager is themed in nix-omarchy-theme.

## Overview

Nautilus is a GTK4 application. Its appearance is controlled by the **GTK theme** and **icon theme** set via `dconf`/`gsettings`. The nix-omarchy-theme module does **not** provide custom Nautilus-specific CSS — it relies entirely on the standard Adwaita/Adwaita-dark theme with overridable color palette variables.

## Current Setup (Omarchy Instance)

This is how Nautilus is themed right now on the Omarchy system this guide was written from:

| Setting         | Value                | Source |
|-----------------|----------------------|--------|
| **GTK Theme**   | `Adwaita-dark`       | Set by `omarchy-theme-set-gnome` via `gsettings` |
| **Color Scheme** | `prefer-dark`        | Derived from absence of `light.mode` file |
| **Icon Theme**  | `Yaru-prussiangreen` | From `~/.config/omarchy/themes/kanso/icons.theme` |
| **Custom GTK CSS** | None loaded      | `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css` are empty |
| **Nautilus-specific CSS** | None          | No CSS file in any theme directory targets Nautilus widget classes |
| **Active Theme** | `kanso`             | A Tokyo Night-inspired dark theme |

**The `omarchy-theme-set-gnome` script** is what bridges Omarchy themes to Nautilus. It checks for `~/.config/omarchy/current/theme/light.mode` and runs:

```bash
if [[ -f ~/.config/omarchy/current/theme/light.mode ]]; then
  gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita"
else
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
fi
```

It then reads the icon theme from `~/.config/omarchy/current/theme/icons.theme` and applies it via `gsettings set org.gnome.desktop.interface icon-theme`.

**The result:** Nautilus looks like standard Adwaita-dark with Yaru-prussiangreen folder/file icons.

## Required Packages

Adwaita is the default GTK theme shipped with GTK itself. No separate "adwaita theme" package is needed.

### Arch Linux / Omarchy

These are already in `omarchy-base.packages`:

| Package | Purpose | Already installed? |
|---------|---------|--------------------|
| `nautilus` + `nautilus-python` | Nautilus itself + Python extensions | Yes |
| `libadwaita` | GTK4 widget library (provides Adwaita theme engine) | Yes |
| `gtk4` | GTK4 toolkit (includes Adwaita theme baked in) | Yes (dependency) |
| `adwaita-icon-theme` | Default icons (dependency of `gtk4`) | Yes |
| `yaru-icon-theme` | Current icon theme used by kanso | Yes |
| `dconf` | gsettings backend for theme persistence | Yes (dependency) |
| `gnome-themes-extra` | Additional Adwaita variants | Yes |
| `gvfs-*` | Volume/trash integration for Nautilus | Yes |

No extra packages are needed. The Adwaita theme is **compiled into the GTK libraries themselves** (`gtk4` and `libadwaita`), not a separate package you install.

### NixOS

```nix
{ pkgs, ... }: {
  programs.nautilus.enable = true;   # Enables nautilus + gvfs + extensions
  environment.systemPackages = with pkgs; [
    libadwaita          # Adwaita theme engine for GTK4
    gtk4                # GTK4 (includes Adwaita theme built-in)
    adwaita-icon-theme  # Default icon theme
    dconf               # gsettings backend
    yaru-icon-theme     # Optional — if using Yaru icons
  ];
}
```

The `programs.nautilus.enable` option in NixOS pulls in Nautilus, gvfs, and tracker miners automatically.

**The result:** Nautilus looks like standard Adwaita-dark with Yaru-prussiangreen folder/file icons. There are no custom CSS overrides — it is completely unmodified from the default GNOME appearance beyond the icon theme. The theme's `gtk.css` (which defines Tokyo Night color variables like `@window_bg_color: #090E13`) is **not consumed by GTK apps** on Omarchy; it only serves as a color palette reference for non-GTK generated templates.

## Theming Pipeline

```
Theme directory (e.g. ~/.themes-src/current/)
├── gtk.theme          → (optional) custom GTK theme name, e.g. "Adwaita"
├── light.mode         → (optional) if present, signals light mode → "Adwaita" + prefer-light
│                        if absent,  defaults to     "Adwaita-dark" + prefer-dark
├── settings.ini       → GTK settings file (auto-generated if missing)
├── gtk.css            → CSS color variables for generated templates
├── icons.theme        → icon theme name, e.g. "Yaru-prussiangreen"
└── backgrounds/       → wallpaper images
```

When a theme is activated (on rebuild or via `theme-switcher`):

1. **`dconf` writes** set the GTK theme, color scheme, icon theme, and cursor theme globally:
   ```
   /org/gnome/desktop/interface/gtk-theme     → "Adwaita" or "Adwaita-dark"
   /org/gnome/desktop/interface/color-scheme  → "prefer-light" or "prefer-dark"
   /org/gnome/desktop/interface/icon-theme    → from icons.theme (or "Adwaita" fallback)
   /org/gnome/desktop/interface/cursor-theme  → from config
   ```

2. **`settings.ini`** is symlinked into `~/.config/gtk-3.0/` and `~/.config/gtk-4.0/` as a fallback
3. **`gtk.css`** (if present) is symlinked into those same directories as a CSS override
4. **Nautilus picks up the changes** without needing a restart — GTK apps re-read dconf on focus

### Determining the GTK Theme

| Condition                                    | GTK Theme      | Color Scheme   |
|----------------------------------------------|----------------|----------------|
| `gtk.theme` file exists                      | Contents of file               |
| `light.mode` file exists (no gtk.theme)      | `Adwaita`      | `prefer-light` |
| Neither file exists                          | `Adwaita-dark` | `prefer-dark`  |

The `gtk.theme` file takes highest priority. If present, its contents (e.g. `"Adwaita"`, `"Tokyo-Night"`, etc.) are used directly as the GTK theme name.

## Nautilus-Specific Customization

The current system has **no Nautilus-specific CSS**. To customize Nautilus beyond the standard Adwaita theme, you have two options:

### Option 1: Global GTK CSS Overrides (any theme)

Add CSS selectors targeting Nautilus widgets to `gtk.css` in your theme. These will be symlinked to `~/.config/gtk-4.0/gtk.css` and read by Nautilus at runtime.

Common Nautilus widget selectors:

```css
/* Nautilus window */
NautilusWindow { }
NautilusWindow .sidebar { }
NautilusWindow .navigation-widget { }

/* Sidebar */
NautilusWindow .sidebar .row { }
NautilusWindow .sidebar .label { }

/* Path bar / location bar */
NautilusPathBar { }
NautilusPathBar button { }

/* Canvas (icon view) */
NautilusCanvasViewContainer { }
NautilusCanvasViewContainer .view { }

/* List view */
NautilusListView { }

/* Floating status bar */
NautilusFloatingStatusBar { }

/* General file chooser dialog (used by all GTK apps) */
filechooser .dialog-action-box { }
filechooser #pathbarbox { }
```

For GTK4 (Nautilus 44+), use CSS class-based selectors instead of widget names:

```css
/* Sidebar styling */
.nautilus-window .sidebar { background-color: @sidebar_bg_color; }

/* List rows */
.nautilus-window .view { }

/* Floating bar at the bottom */
.floating-bar { }
```

### Option 2: Nautilus Style Sheet via `gtk-4.0` Override

Nautilus supports per-app CSS overrides at `~/.config/gtk-4.0/gtk.css` — which is what the theme's `gtk.css` is symlinked to. Anything in that file applies to all GTK4 apps including Nautilus.

To scope rules to Nautilus only, use the `.nautilus-window` class (GTK4):

```css
/* Only affects Nautilus */
.nautilus-window { font-size: 14px; }
.nautilus-window .sidebar { padding: 8px; }
```

## Icon Theme

The icon theme set via `dconf` affects Nautilus's file/folder icons. Set it in `icons.theme`:

```
# ~/.themes-src/current/icons.theme
Yaru-prussiangreen
```

The `theme-switcher` script reads this file and applies it via dconf:

```bash
ICON_THEME=$(cat "$CURRENT/icons.theme" 2>/dev/null || echo "Adwaita")
dconf write /org/gnome/desktop/interface/icon-theme "'$ICON_THEME'"
```

## Current Limitations

- **No Nautilus-specific templates** are rendered by default (unlike Hyprland, Waybar, etc.)
- Custom GTK CSS only works if the theme ships a `gtk.css` — the `gtk.css` template in `templates/` is only used when the theme doesn't provide its own
- Nautilus respects the OS color scheme preference (`prefer-dark`/`prefer-light`) which may override some CSS

## Adding Nautilus CSS to a Theme

To add Nautilus styling to a theme, create a `gtk.css` file in the theme repository root (next to `colors.toml`). Since theme files take precedence over templates, this `gtk.css` will be used directly instead of the auto-generated one.

Example `gtk.css` for a dark theme with Nautilus sidebar customization:

```css
/* Color variables */
@define-color window_bg_color #090E13;
@define-color window_fg_color #C5C9C7;
@define-color sidebar_bg_color #0D1419;
@define-color view_bg_color #090E13;
@define-color accent_bg_color #8ba4b0;
@define-color borders alpha(#C5C9C7, 0.1);

/* Nautilus sidebar */
.nautilus-window .sidebar {
    background-color: @sidebar_bg_color;
    border-right: 1px solid @borders;
}

.nautilus-window .sidebar .row:selected {
    background-color: @accent_bg_color;
    color: @window_bg_color;
}

/* File chooser dialog borders */
filechooser .dialog-action-box {
    border-top: 1px solid @borders;
}

filechooser #pathbarbox {
    border-bottom: 1px solid @borders;
}
```
