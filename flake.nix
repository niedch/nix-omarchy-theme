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
              fi
            '';

            xdg.configFile = lib.mapAttrs' (target: symlink:
              lib.nameValuePair target {
                source = config.lib.file.mkOutOfStoreSymlink
                  "${currentLink}/${symlink.source}";
                recursive = symlink.recursive;
              }
            ) cfg.symlinks;

            home.packages = [
              pkgs.libnotify
              (pkgs.writeShellScriptBin "theme-switcher" ''
                set -euo pipefail

                THEMES_DIR="${themesDir}"
                CURRENT="${currentLink}"

                THEME=$(ls -1 "$THEMES_DIR" | grep -v '^current$' | sort | ${cfg.selectorCommand} 2>/dev/null || echo "")

                if [ -n "$THEME" ] && [ -d "$THEMES_DIR/$THEME" ]; then
                  ln -sfn "$THEMES_DIR/$THEME" "$CURRENT"
                  notify-send "Theme Switched" "$THEME" -i preferences-desktop-theme
                  hyprctl reload 2>/dev/null || true
                fi
              '')
            ];

            programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable ''
              alias ts="theme-switcher"
            '';
          };
        };
    };
}
