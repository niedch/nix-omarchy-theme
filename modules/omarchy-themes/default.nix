{
  lib,
  pkgs,
  defaultTemplates,
  colors,
  render,
}: {config, ...}: let
  cfg = config.omarchy-themes;
  themesDir = "${config.home.homeDirectory}/.themes-src";
  currentLink = "${themesDir}/current";
  buildTheme = import ./build-theme.nix {inherit lib pkgs render;};
  inherit (import ./options.nix {inherit lib pkgs defaultTemplates;}) options;
in {
  inherit options;

  config = lib.mkIf cfg.enable {
    home.activation.setupThemes = lib.hm.dag.entryAfter ["writeBoundary"] ''
            THEMES_DIR="${themesDir}"
            mkdir -p "$THEMES_DIR"

            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: ''
          theme_path="${buildTheme {
            inherit name theme;
            templates = cfg.templates;
          }}"
          if [ ! "$(readlink -f "$THEMES_DIR/${name}" 2>/dev/null)" = "$theme_path" ]; then
            ln -sfn "$theme_path" "$THEMES_DIR/${name}"
          fi
        '')
        cfg.themes)}

            if [ -d "$THEMES_DIR/${cfg.defaultTheme}" ]; then
              ln -sfn "$THEMES_DIR/${cfg.defaultTheme}" "$THEMES_DIR/current"

              DEFAULT_BG=""
              DEFAULT_BG_FILE="$THEMES_DIR/current/default-background"
              if [ -f "$DEFAULT_BG_FILE" ]; then
                DEFAULT_BG=$(cat "$DEFAULT_BG_FILE")
                if [ ! -f "$THEMES_DIR/current/backgrounds/$DEFAULT_BG" ]; then
                  DEFAULT_BG=""
                fi
              fi
              FIRST_BG="''${DEFAULT_BG:-$(ls -1 "$THEMES_DIR/current/backgrounds/" 2>/dev/null | head -1 || echo "")}"
              if [ -n "$FIRST_BG" ]; then
                ln -sfn "$THEMES_DIR/current/backgrounds/$FIRST_BG" "$THEMES_DIR/current-background"
              fi

              GSETTINGS_SCHEMA_DIR="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${pkgs.gsettings-desktop-schemas.version}/glib-2.0/schemas"
              CURRENT="$THEMES_DIR/current"
              if [ -f "$CURRENT/gtk.theme" ]; then
                GTK_THEME=$(cat "$CURRENT/gtk.theme")
              elif [ -f "$CURRENT/light.mode" ]; then
                GTK_THEME="Adwaita"
              else
                GTK_THEME="Adwaita-dark"
              fi
              ${pkgs.glib.bin}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
              ${pkgs.glib.bin}/bin/gsettings set org.gnome.desktop.interface color-scheme \
                "$([ -f "$CURRENT/light.mode" ] && echo "prefer-light" || echo "prefer-dark")" 2>/dev/null || true
              ICON_THEME=$(cat "$CURRENT/icons.theme" 2>/dev/null || echo "Adwaita")
              ${pkgs.glib.bin}/bin/gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true

              mkdir -p "$HOME/.config/gtk-3.0"
              ln -sfn "$CURRENT/settings-3.0.ini" "$HOME/.config/gtk-3.0/settings.ini"
              mkdir -p "$HOME/.config/gtk-4.0"
              ln -sfn "$CURRENT/settings-4.0.ini" "$HOME/.config/gtk-4.0/settings.ini"

              THEME_HEX="#1c2027"
              if [ -f "$CURRENT/chromium.theme" ]; then
                CHROMIUM_RGB=$(cat "$CURRENT/chromium.theme")
                THEME_HEX=$(printf '#%02x%02x%02x' $(echo "$CHROMIUM_RGB" | tr ',' ' ') 2>/dev/null || echo "#1c2027")
              fi
              for policy_dir in \
                "$HOME/.config/brave/Policies/managed" \
                "$HOME/.config/brave/policies/managed" \
                "$HOME/.config/chromium/Policies/managed" \
                "$HOME/.config/chromium/policies/managed" \
                "$HOME/.config/google-chrome/Policies/managed" \
                "$HOME/.config/google-chrome/policies/managed" \
                "$HOME/.config/microsoft-edge/Policies/managed" \
                "$HOME/.config/microsoft-edge/policies/managed" \
                "$HOME/.config/BraveSoftware/Brave-Browser/Policies/managed" \
                "$HOME/.config/BraveSoftware/Brave-Browser/policies/managed"; do
                mkdir -p "$policy_dir"
                cat > "$policy_dir/color.json" << EOF
      {"BrowserThemeColor": "$THEME_HEX"}
      EOF
            done

              :
            fi
    '';

    xdg.configFile =
      lib.mapAttrs' (
        target: symlink:
          lib.nameValuePair target {
            source =
              config.lib.file.mkOutOfStoreSymlink
              "${currentLink}/${symlink.source}";
            recursive = symlink.recursive;
          }
      )
      cfg.symlinks;

    home.packages = with pkgs; [
      dconf
      glib
      gsettings-desktop-schemas
      gtk4
      libadwaita
      adwaita-icon-theme
      libnotify
      (writeShellScriptBin "theme-switcher" ''
                set -euo pipefail

                export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
                export GSETTINGS_SCHEMA_DIR="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${pkgs.gsettings-desktop-schemas.version}/glib-2.0/schemas"

                THEMES_DIR="${themesDir}"
                CURRENT="${currentLink}"

                THEME=$(ls -1 "$THEMES_DIR" | grep -v -E '^(current|current-background)$' | sort | ${cfg.selectorCommand} 2>/dev/null || echo "")

                if [ -z "$THEME" ] || [ ! -d "$THEMES_DIR/$THEME" ]; then
                  exit 0
                fi

                ln -sfn "$THEMES_DIR/$THEME" "$CURRENT"

                if [ -f "$CURRENT/gtk.theme" ]; then
                  GTK_THEME=$(cat "$CURRENT/gtk.theme")
                elif [ -f "$CURRENT/light.mode" ]; then
                  GTK_THEME="Adwaita"
                else
                  GTK_THEME="Adwaita-dark"
                fi
                ${pkgs.glib.bin}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
                ${pkgs.glib.bin}/bin/gsettings set org.gnome.desktop.interface color-scheme \
                  "$([ -f "$CURRENT/light.mode" ] && echo "prefer-light" || echo "prefer-dark")" 2>/dev/null || true
                ICON_THEME=$(cat "$CURRENT/icons.theme" 2>/dev/null || echo "Adwaita")
                ${pkgs.glib.bin}/bin/gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true

                mkdir -p "$HOME/.config/gtk-3.0"
                ln -sfn "$CURRENT/settings-3.0.ini" "$HOME/.config/gtk-3.0/settings.ini"
                mkdir -p "$HOME/.config/gtk-4.0"
                ln -sfn "$CURRENT/settings-4.0.ini" "$HOME/.config/gtk-4.0/settings.ini"

                THEME_HEX="#1c2027"
                if [ -f "$CURRENT/chromium.theme" ]; then
                  CHROMIUM_RGB=$(cat "$CURRENT/chromium.theme")
                  THEME_HEX=$(printf '#%02x%02x%02x' $(echo "$CHROMIUM_RGB" | tr ',' ' ') 2>/dev/null || echo "#1c2027")
                fi
                for policy_dir in \
                  "$HOME/.config/brave/Policies/managed" \
                  "$HOME/.config/brave/policies/managed" \
                  "$HOME/.config/chromium/Policies/managed" \
                  "$HOME/.config/chromium/policies/managed" \
                  "$HOME/.config/google-chrome/Policies/managed" \
                  "$HOME/.config/google-chrome/policies/managed" \
                  "$HOME/.config/microsoft-edge/Policies/managed" \
                  "$HOME/.config/microsoft-edge/policies/managed" \
                  "$HOME/.config/BraveSoftware/Brave-Browser/Policies/managed" \
                  "$HOME/.config/BraveSoftware/Brave-Browser/policies/managed"; do
                  mkdir -p "$policy_dir"
                  cat > "$policy_dir/color.json" << EOF
      {"BrowserThemeColor": "$THEME_HEX"}
      EOF
                done

                CURRENT_BG="${themesDir}/current-background"
                DEFAULT_BG=""
                DEFAULT_BG_FILE="$CURRENT/default-background"
                if [ -f "$DEFAULT_BG_FILE" ]; then
                  DEFAULT_BG=$(cat "$DEFAULT_BG_FILE")
                  if [ ! -f "$CURRENT/backgrounds/$DEFAULT_BG" ]; then
                    DEFAULT_BG=""
                  fi
                fi
                FIRST_BG="''${DEFAULT_BG:-$(ls -1 "$CURRENT/backgrounds/" 2>/dev/null | head -1 || echo "")}"
                if [ -n "$FIRST_BG" ]; then
                  PREV_BG=$(readlink "$CURRENT_BG" 2>/dev/null || echo "")
                  PREV_BG_NAME=$(basename "$PREV_BG" 2>/dev/null || echo "")
                  if [ -n "$PREV_BG_NAME" ] && [ -f "$CURRENT/backgrounds/$PREV_BG_NAME" ]; then
                    ln -sfn "$CURRENT/backgrounds/$PREV_BG_NAME" "$CURRENT_BG"
                  else
                    ln -sfn "$CURRENT/backgrounds/$FIRST_BG" "$CURRENT_BG"
                  fi
                fi

                hyprctl reload 2>/dev/null || true
                pkill -USR2 ghostty 2>/dev/null || true
                makoctl reload 2>/dev/null || true

                systemctl --user restart elephant.service walker.service swaybg.service waybar.service 2>/dev/null || true

                pkill -SIGUSR2 btop 2>/dev/null || true
                pkill -USR2 opencode 2>/dev/null || true

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

        systemctl --user restart swaybg.service 2>/dev/null || true

        notify-send "Background Changed" "$BG"
      '')
    ];

    programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable ''
      alias ts="theme-switcher"
    '';
  };
}
