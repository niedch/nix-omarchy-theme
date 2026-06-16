{
  lib,
  pkgs,
  defaultTemplates,
}: {
  options.omarchy-themes = {
    enable = lib.mkEnableOption "multi-theme manager with live switching";

    defaultTheme = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Theme activated by default on rebuild";
    };

    selectorCommand = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.wofi}/bin/wofi --show dmenu --prompt \"Select Theme\" --width 500 --height 400";
      description = ''
        Command that displays a list from stdin and outputs the selected item
      '';
      example = "${pkgs.fzf}/bin/fzf --prompt=\"Select Theme \"";
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
          defaultBackground = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Default background filename. null = use first file alphabetically.";
          };
        };
      });
      default = {};
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
      default = {};
      example = {
        hypr = {};
        waybar = {};
        wallpapers = {source = "wallpapers";};
      };
      description = ''
        XDG config directories to symlink from the current theme.
        Keys are XDG config directory names, values specify theme repo source subpaths.
      '';
    };
  };
}
