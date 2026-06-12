{ lib, pkgs, defaultTemplates, colors, render }:
{ config, ... }:
let
  cfg = config.omarchy-themes;
  themesDir = "${config.home.homeDirectory}/.themes-src";
  currentLink = "${themesDir}/current";
  buildTheme = import ./build-theme.nix { inherit lib pkgs render; };
  inherit (import ./options.nix { inherit lib pkgs defaultTemplates; }) options;
in {
  inherit options;

  config = lib.mkIf cfg.enable {
    home.activation.setupThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      THEMES_DIR="${themesDir}"
      mkdir -p "$THEMES_DIR"

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: ''
        theme_path="${buildTheme { inherit name theme; templates = cfg.templates; cursorThemeName = cfg.gtk.cursorTheme.name; cursorThemeSize = cfg.gtk.cursorTheme.size; }}"
        if [ ! "$(readlink -f "$THEMES_DIR/${name}" 2>/dev/null)" = "$theme_path" ]; then
          ln -sfn "$theme_path" "$THEMES_DIR/${name}"
        fi
      '') cfg.themes)}

      if [ -d "$THEMES_DIR/${cfg.defaultTheme}" ]; then
        ln -sfn "$THEMES_DIR/${cfg.defaultTheme}" "$THEMES_DIR/current"

        FIRST_BG=$(ls -1 "$THEMES_DIR/current/backgrounds/" 2>/dev/null | head -1 || echo "")
        if [ -n "$FIRST_BG" ]; then
          ln -sfn "$THEMES_DIR/current/backgrounds/$FIRST_BG" "$THEMES_DIR/current-background"
        fi

        GTK_THEME_FILE="$THEMES_DIR/current/gtk.theme"
        if [ -f "$GTK_THEME_FILE" ]; then
          GTK_THEME=$(cat "$GTK_THEME_FILE")
        elif [ -f "$THEMES_DIR/current/light.mode" ]; then
          GTK_THEME="Adwaita"
        else
          GTK_THEME="Adwaita-dark"
        fi
        if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME'"
          if [ -f "$THEMES_DIR/current/light.mode" ]; then
            ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
          else
            ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
          fi
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/cursor-theme "'${cfg.gtk.cursorTheme.name}'"
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/cursor-size ${toString cfg.gtk.cursorTheme.size}
        fi

        if [ -f "$THEMES_DIR/current/light.mode" ]; then
          GTK_THEME_EXPORT="$GTK_THEME"
        else
          case "$GTK_THEME" in
            *-dark) GTK_THEME_EXPORT="$GTK_THEME" ;;
            *)      GTK_THEME_EXPORT="$GTK_THEME:dark" ;;
          esac
        fi
        mkdir -p "$HOME/.config/environment.d"
        echo "GTK_THEME=$GTK_THEME_EXPORT" > "$HOME/.config/environment.d/theme.conf"
        ${pkgs.systemd}/bin/systemctl --user import-environment GTK_THEME

        for dir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
          mkdir -p "$dir"
          rm -f "$dir/settings.ini" "$dir/gtk.css" 2>/dev/null || true
          ln -sfn "$THEMES_DIR/current/settings.ini" "$dir/settings.ini" 2>/dev/null || true
          ln -sfn "$THEMES_DIR/current/gtk.css" "$dir/gtk.css" 2>/dev/null || true
        done
      fi
    '';

    xdg.configFile = lib.mapAttrs' (target: symlink:
      lib.nameValuePair target {
        source = config.lib.file.mkOutOfStoreSymlink
          "${currentLink}/${symlink.source}";
        recursive = symlink.recursive;
      }
    ) cfg.symlinks;

    home.packages = with pkgs; [
      libnotify
      (writeShellScriptBin "theme-switcher" ''
        set -euo pipefail

        THEMES_DIR="${themesDir}"
        CURRENT="${currentLink}"

        THEME=$(ls -1 "$THEMES_DIR" | grep -v '^current$' | sort | ${cfg.selectorCommand} 2>/dev/null || echo "")

        if [ -z "$THEME" ] || [ ! -d "$THEMES_DIR/$THEME" ]; then
          exit 0
        fi

        ln -sfn "$THEMES_DIR/$THEME" "$CURRENT"

        CURRENT_BG="${themesDir}/current-background"
        FIRST_BG=$(ls -1 "$CURRENT/backgrounds/" 2>/dev/null | head -1 || echo "")
        if [ -n "$FIRST_BG" ]; then
          PREV_BG=$(readlink "$CURRENT_BG" 2>/dev/null || echo "")
          PREV_BG_NAME=$(basename "$PREV_BG" 2>/dev/null || echo "")
          if [ -n "$PREV_BG_NAME" ] && [ -f "$CURRENT/backgrounds/$PREV_BG_NAME" ]; then
            ln -sfn "$CURRENT/backgrounds/$PREV_BG_NAME" "$CURRENT_BG"
          else
            ln -sfn "$CURRENT/backgrounds/$FIRST_BG" "$CURRENT_BG"
          fi
          pkill swaybg 2>/dev/null || true
          setsid swaybg -i "$CURRENT_BG" -m fill &>/dev/null &
        fi

        hyprctl reload 2>/dev/null || true

        pkill waybar 2>/dev/null || true
        if systemctl --user --quiet is-active waybar 2>/dev/null; then
          systemctl --user restart waybar 2>/dev/null || true
        else
          setsid waybar &>/dev/null &
        fi

        pkill -USR2 ghostty 2>/dev/null || true

        makoctl reload 2>/dev/null || true

        systemctl --user restart elephant.service walker.service 2>/dev/null || true

        pkill -SIGUSR2 btop 2>/dev/null || true

        pkill -USR2 opencode 2>/dev/null || true

        ICON_THEME=$(cat "$CURRENT/icons.theme" 2>/dev/null || echo "Adwaita")
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme "'$ICON_THEME'"
        GTK_THEME_FILE="$CURRENT/gtk.theme"
        if [ -f "$GTK_THEME_FILE" ]; then
          GTK_THEME=$(cat "$GTK_THEME_FILE")
        elif [ -f "$CURRENT/light.mode" ]; then
          GTK_THEME="Adwaita"
        else
          GTK_THEME="Adwaita-dark"
        fi
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME'"
        if [ -f "$CURRENT/light.mode" ]; then
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
        else
          ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
        fi
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/cursor-theme "'${cfg.gtk.cursorTheme.name}'"
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/cursor-size ${toString cfg.gtk.cursorTheme.size}

        if [ -f "$CURRENT/light.mode" ]; then
          GTK_THEME_EXPORT="$GTK_THEME"
        else
          case "$GTK_THEME" in
            *-dark) GTK_THEME_EXPORT="$GTK_THEME" ;;
            *)      GTK_THEME_EXPORT="$GTK_THEME:dark" ;;
          esac
        fi
        mkdir -p "$HOME/.config/environment.d"
        echo "GTK_THEME=$GTK_THEME_EXPORT" > "$HOME/.config/environment.d/theme.conf"
        ${pkgs.systemd}/bin/systemctl --user import-environment GTK_THEME

        for dir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
          mkdir -p "$dir"
          rm -f "$dir/settings.ini" "$dir/gtk.css" 2>/dev/null || true
          ln -sfn "$CURRENT/settings.ini" "$dir/settings.ini" 2>/dev/null || true
          ln -sfn "$CURRENT/gtk.css" "$dir/gtk.css" 2>/dev/null || true
        done

        HOOK_DIR="$HOME/.config/theme-switcher/hooks/theme-set.d"
        if [ -d "$HOOK_DIR" ]; then
          for hook in "$HOOK_DIR"/*; do
            [ -x "$hook" ] && "$hook" "$THEME"
          done
        fi
        if [ -x "$HOME/.config/theme-switcher/hooks/theme-set" ]; then
          "$HOME/.config/theme-switcher/hooks/theme-set" "$THEME"
        fi

        notify-send "Theme Switched" "$THEME" -i preferences-desktop-theme
      '')
      (writeShellScriptBin "theme-wallpaper" ''
        set -euo pipefail

        THEMES_DIR="${themesDir}"
        CURRENT="${currentLink}"
        CURRENT_BG="${themesDir}/current-background"

        BG_DIR="$CURRENT/backgrounds"
        if [ ! -d "$BG_DIR" ]; then
          notify-send "No Backgrounds" "Current theme has no backgrounds directory"
          exit 0
        fi

        BG=$(ls -1 "$BG_DIR" | sort | ${cfg.selectorCommand} 2>/dev/null || echo "")

        if [ -z "$BG" ]; then
          exit 0
        fi

        ln -sfn "$BG_DIR/$BG" "$CURRENT_BG"

        pkill swaybg 2>/dev/null || true
        setsid swaybg -i "$CURRENT_BG" -m fill &>/dev/null &

        notify-send "Background Changed" "$BG"
      '')
    ] ++ lib.optional (cfg.gtk.cursorTheme.package != null) cfg.gtk.cursorTheme.package;

    programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable ''
      alias ts="theme-switcher"
    '';
  };
}
