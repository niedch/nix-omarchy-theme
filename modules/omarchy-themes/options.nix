{
  lib,
  pkgs,
  defaultTemplates,
  afterHooks,
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
          extraBackgrounds = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  description = "Direct URL to download the background image from";
                };
                hash = lib.mkOption {
                  type = lib.types.str;
                  description = "SRI hash of the downloaded file (e.g. sha256-...)";
                };
                filename = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Override filename in backgrounds/. Defaults to URL basename.";
                };
              };
            });
            default = [];
            description = ''
              Extra background images to download into the theme's backgrounds/ directory.
              Each entry specifies a direct image URL and its expected hash.
              The filename is derived from the URL by default, or can be overridden.
            '';
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
        "ghostty.conf.tpl" = ''
          background = {{ background }}
          foreground = {{ foreground }}
          palette = 0={{ color0 }}
        '';
      };
    };

    afterHooks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = afterHooks;
      defaultText = lib.literalMD "Built-in reload + notify hooks";
      description = ''
        Hook scripts installed to theme-set.d/. Keys determine ordering (sorted alphabetically).
        Each hook receives the theme name as $1.
      '';
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
