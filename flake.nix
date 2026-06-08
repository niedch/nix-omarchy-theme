{
  description = "Declarative multi-theme manager for NixOS + Hyprland";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
    in
    {
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.omarchy-themes;
          themesDir = "${config.home.homeDirectory}/.themes-src";
          currentLink = "${themesDir}/current";
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
              description = "Command that displays a list from stdin and outputs the selected item";
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
                };
              });
              default = {};
              description = "Attribute set of theme definitions";
            };

            symlinks = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  source = lib.mkOption {
                    type = lib.types.str;
                    default = ".";
                    description = "Relative path inside theme repo to link from";
                  };
                  recursive = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Symlink recursively";
                  };
                };
              });
              default = {};
              example = {
                hypr = {};
                waybar = {};
                wallpapers = { source = "wallpapers"; };
              };
              description = ''
                XDG config directories to symlink from the current theme.
                Keys are XDG config directory names, values specify theme repo source subpaths.
              '';
            };
          };

          config = lib.mkIf cfg.enable {
            home.activation.setupThemes = lib.hm.dag.entryAfter ["writeBoundary"] ''
              THEMES_DIR="${themesDir}"
              mkdir -p "$THEMES_DIR"

              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: ''
                ln -sfn ${pkgs.fetchgit { url = theme.url; rev = "refs/heads/${theme.ref}"; hash = "sha256-AfwCqhF7WMtavS+Z1YTO1YU3XsfGiwDyGhjhzYyvsfY="; }} "$THEMES_DIR/${name}"
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
