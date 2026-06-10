{
  description = "Declarative multi-theme manager for NixOS + Hyprland";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      # ---- Hex color helpers ----

      hexMap = {
        "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4;
        "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9;
        "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
      };

      hexToDec = hex:
        let
          h = lib.toLower hex;
          c0 = hexMap.${builtins.substring 0 1 h};
          c1 = hexMap.${builtins.substring 1 1 h};
        in
        c0 * 16 + c1;

      hexToRgb = hex:
        let
          h = lib.removePrefix "#" hex;
        in
        "${toString (hexToDec (builtins.substring 0 2 h))},${toString (hexToDec (builtins.substring 2 2 h))},${toString (hexToDec (builtins.substring 4 2 h))}";

      # ---- Template rendering ----

      buildReplacements = colors:
        lib.foldlAttrs (acc: k: v:
          if lib.hasPrefix "#" v then
            {
              searches = acc.searches ++ [ "{{ ${k} }}" "{{ ${k}_strip }}" "{{ ${k}_rgb }}" ];
              replaces = acc.replaces ++ [ v (lib.removePrefix "#" v) (hexToRgb v) ];
            }
          else
            {
              searches = acc.searches ++ [ "{{ ${k} }}" ];
              replaces = acc.replaces ++ [ v ];
            }
        ) { searches = [ ]; replaces = [ ]; } colors;

      renderTemplate = colors: template:
        let r = buildReplacements colors;
        in builtins.replaceStrings r.searches r.replaces template;

      # ---- Default templates (Omarchy's built-in) ----
      defaultTemplates = import ./templates;
    in
    {
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.omarchy-themes;
          themesDir = "${config.home.homeDirectory}/.themes-src";
          currentLink = "${themesDir}/current";

          buildTheme = name: theme:
            let
              themeSrc = pkgs.fetchgit {
                url = theme.url;
                rev = theme.ref;
                hash = theme.hash;
              };
              themeRoot = "${themeSrc}/${theme.subpath}";
              colorsFile = "${themeRoot}/colors.toml";
              hasColors = builtins.pathExists colorsFile;
              colors = if hasColors then builtins.fromTOML (builtins.readFile colorsFile) else { };
              rendered = if hasColors then
                lib.mapAttrs (n: t: renderTemplate colors t) cfg.templates
              else { };
              renderedFiles = lib.mapAttrs' (n: content:
                lib.nameValuePair n (pkgs.writeText "omarchy-${name}-${n}" content)
              ) rendered;

              gtkThemeFile = "${themeRoot}/gtk.theme";
              hasGtkTheme = builtins.pathExists gtkThemeFile;
              isLight = builtins.pathExists "${themeRoot}/light.mode";
              gtkThemeName = if hasGtkTheme then lib.strings.removeSuffix "\n" (builtins.readFile gtkThemeFile)
                             else if isLight then "Adwaita"
                             else "Adwaita-dark";
              colorScheme = if isLight then "prefer-light" else "prefer-dark";
              settingsIni = pkgs.writeText "settings-${name}.ini" ''
                [Settings]
                gtk-theme-name=${gtkThemeName}
                gtk-cursor-theme-name=${cfg.gtk.cursorTheme.name}
                gtk-cursor-theme-size=${toString cfg.gtk.cursorTheme.size}
                gtk-application-prefer-dark-theme=${if isLight then "0" else "1"}
                color-scheme=${colorScheme}
              '';
            in
            pkgs.runCommandLocal "omarchy-theme-${name}" { } ''
              mkdir -p "$out"

              # Copy all original theme source files from subpath
              cp -r ${themeRoot}/* "$out/"

              # Remove .git metadata
              rm -rf "$out/.git" 2>/dev/null || true

              # Render templates not already provided by the theme
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: filePath: ''
                if [ ! -f "$out/${lib.escapeShellArg n}" ]; then
                  cp "${filePath}" "$out/${lib.escapeShellArg n}"
                fi
              '') renderedFiles)}

              # Generate settings.ini if the theme doesn't ship its own
              if [ ! -f "$out/settings.ini" ]; then
                cp "${settingsIni}" "$out/settings.ini"
              fi
            '';
        in
        {
          options.omarchy-themes = {
            enable = lib.mkEnableOption "multi-theme manager with live switching";

            defaultTheme = lib.mkOption {
              type = lib.types.str;
              default = "default";
              description = "Theme activated by default on rebuild";
            };

            selectorCommand = lib.mkOption {
              type = lib.types.str;
              default = ''${pkgs.wofi}/bin/wofi --show dmenu --prompt "Select Theme" --width 500 --height 400'';
              description = ''
                Command that displays a list from stdin and outputs the selected item
              '';
              example = ''${pkgs.fzf}/bin/fzf --prompt="Select Theme "'';
            };

            themes = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  url = lib.mkOption {
                    type = lib.types.str;
                    description = "Git repository URL";
                  };
                  ref = lib.mkOption {
                    type = lib.types.str;
                    default = "main";
                    description = "Branch, tag, or commit SHA";
                  };
                  hash = lib.mkOption {
                    type = lib.types.str;
                    description = "SRI hash of the fetched source (e.g. sha256-...)";
                  };
                  subpath = lib.mkOption {
                    type = lib.types.str;
                    default = ".";
                    description = "Subdirectory within the repo containing the theme";
                  };
                };
              });
              default = { };
              description = "Attribute set of theme definitions";
            };

            templates = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = defaultTemplates;
              defaultText = lib.literalMD "Omarchy's built-in templates (17 apps)";
              description = ''
                Template name → template content with {{ key }}, {{ key_strip }}, {{ key_rgb }} placeholders.
                Templates are rendered from the theme's colors.toml at build time.
                If a theme ships its own file with the same name, the theme file takes precedence.
              '';
              example = {
                "ghostty.conf" = ''
                  background = {{ background }}
                  foreground = {{ foreground }}
                  palette = 0={{ color0 }}
                '';
              };
            };

            symlinks = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  source = lib.mkOption {
                    type = lib.types.str;
                    default = ".";
                    description = "Relative path inside theme to link from";
                  };
                  recursive = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Symlink recursively";
                  };
                };
              });
              default = { };
              example = {
                hypr = { };
                waybar = { };
                wallpapers = { source = "wallpapers"; };
              };
              description = ''
                XDG config directories to symlink from the current theme.
                Keys are XDG config directory names, values specify theme repo source subpaths.
              '';
            };

            gtk = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  cursorTheme = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      default = "Adwaita";
                      description = "Cursor theme name";
                    };
                    size = lib.mkOption {
                      type = lib.types.int;
                      default = 24;
                      description = "Cursor size";
                    };
                    package = lib.mkOption {
                      type = lib.types.nullOr lib.types.package;
                      default = null;
                      description = "Cursor theme package to install";
                    };
                  };
                };
              };
              default = { };
              description = "GTK configuration";
            };
          };

          config = lib.mkIf cfg.enable {
            home.activation.setupThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              THEMES_DIR="${themesDir}"
              mkdir -p "$THEMES_DIR"

              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: ''
                theme_path="${buildTheme name theme}"
                if [ ! "$(readlink -f "$THEMES_DIR/${name}" 2>/dev/null)" = "$theme_path" ]; then
                  ln -sfn "$theme_path" "$THEMES_DIR/${name}"
                fi
              '') cfg.themes)}

              if [ -d "$THEMES_DIR/${cfg.defaultTheme}" ]; then
                ln -sfn "$THEMES_DIR/${cfg.defaultTheme}" "$THEMES_DIR/current"

                GTK_THEME_FILE="$THEMES_DIR/current/gtk.theme"
                if [ -f "$GTK_THEME_FILE" ]; then
                  GTK_THEME=$(cat "$GTK_THEME_FILE")
                elif [ -f "$THEMES_DIR/current/light.mode" ]; then
                  GTK_THEME="Adwaita"
                else
                  GTK_THEME="Adwaita-dark"
                fi
                ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME'"
                if [ -f "$THEMES_DIR/current/light.mode" ]; then
                  ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
                else
                  ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
                fi
                ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/cursor-theme "'${cfg.gtk.cursorTheme.name}'"
                ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/cursor-size ${toString cfg.gtk.cursorTheme.size}
              fi

              # Point GTK config files at current theme via runtime symlinks
              for dir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
                mkdir -p "$dir"
                rm -f "$dir/settings.ini" "$dir/gtk.css" 2>/dev/null || true
                ln -sfn "$THEMES_DIR/current/settings.ini" "$dir/settings.ini" 2>/dev/null || true
                ln -sfn "$THEMES_DIR/current/gtk.css" "$dir/gtk.css" 2>/dev/null || true
              done
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

                # Atomic symlink swap
                ln -sfn "$THEMES_DIR/$THEME" "$CURRENT"

                # --- Reload Cascade ---

                # 1. Hyprland
                hyprctl reload 2>/dev/null || true

                # 2. Waybar (kill existing instances, then restart via systemd or relaunch)
                pkill waybar 2>/dev/null || true
                if systemctl --user --quiet is-active waybar 2>/dev/null; then
                  systemctl --user restart waybar 2>/dev/null || true
                else
                  setsid waybar &>/dev/null &
                fi

                # 3. Ghostty (SIGUSR2 reloads color config)
                pkill -USR2 ghostty 2>/dev/null || true

                # 4. Mako (reload config)
                makoctl reload 2>/dev/null || true

                # 5. Walker / Elephant (systemd restart)
                systemctl --user restart elephant.service walker.service 2>/dev/null || true

                # 6. btop (SIGUSR2 reloads theme)
                pkill -SIGUSR2 btop 2>/dev/null || true

                # 7. opencode (SIGUSR2 reloads config)
                pkill -USR2 opencode 2>/dev/null || true

                # 8. GTK/GNOME settings
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

                # Copy GTK settings.ini and gtk.css for runtime use
                for dir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
                  mkdir -p "$dir"
                  rm -f "$dir/settings.ini" "$dir/gtk.css" 2>/dev/null || true
                  ln -sfn "$CURRENT/settings.ini" "$dir/settings.ini" 2>/dev/null || true
                  ln -sfn "$CURRENT/gtk.css" "$dir/gtk.css" 2>/dev/null || true
                done

                # 9. User hooks
                HOOK_DIR="$HOME/.config/theme-switcher/hooks/theme-set.d"
                if [ -d "$HOOK_DIR" ]; then
                  for hook in "$HOOK_DIR"/*; do
                    [ -x "$hook" ] && "$hook" "$THEME"
                  done
                fi
                if [ -x "$HOME/.config/theme-switcher/hooks/theme-set" ]; then
                  "$HOME/.config/theme-switcher/hooks/theme-set" "$THEME"
                fi

                # 10. Notification
                notify-send "Theme Switched" "$THEME" -i preferences-desktop-theme
              '')
            ] ++ lib.optional (cfg.gtk.cursorTheme.package != null) cfg.gtk.cursorTheme.package;

            programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable ''
              alias ts="theme-switcher"
            '';
          };
        };
    };
}
