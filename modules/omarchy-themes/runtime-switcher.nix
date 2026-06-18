{
  lib,
  pkgs,
  defaultTemplates,
  afterHooks,
  colors,
  render,
}: {config, ...}: let
  cfg = config.omarchy-themes;
  themesDir = "${config.home.homeDirectory}/.local/share/themes";
  currentLink = "${themesDir}/current";
  buildTheme = import ./build-theme.nix {inherit lib pkgs render;};
  scripts = import ./scripts.nix {inherit pkgs;};
  inherit (import ./options.nix {inherit lib pkgs defaultTemplates afterHooks;}) options;
in {
  inherit options;

  config = lib.mkIf cfg.enable {
    home.activation.setupThemes = lib.hm.dag.entryAfter ["writeBoundary"] ''
      THEMES_DIR="${themesDir}"
      CURRENT="$THEMES_DIR/current"
      CURRENT_BG="$THEMES_DIR/current-background"
      mkdir -p "$THEMES_DIR"

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: ''
          theme_path="${buildTheme {
            inherit name theme;
            templates = defaultTemplates // cfg.templates;
          }}"
          if [ ! "$(readlink -f "$THEMES_DIR/${name}" 2>/dev/null)" = "$theme_path" ]; then
            ln -sfn "$theme_path" "$THEMES_DIR/${name}"
          fi
        '')
        cfg.themes)}

      if [ -d "$THEMES_DIR/${cfg.defaultTheme}" ]; then
        ln -sfn "$THEMES_DIR/${cfg.defaultTheme}" "$CURRENT"

        ${scripts.selectBackground {preserveCurrentBg = false;}}

        ${scripts.exportGsettingsSchemas}
        ${scripts.applyGtkConfig}
        ${scripts.applyChromiumColor}
        :
      fi
    '';

    xdg.configFile =
      (lib.mapAttrs' (
          target: symlink:
            lib.nameValuePair target {
              source =
                config.lib.file.mkOutOfStoreSymlink
                "${currentLink}/${symlink.source}";
              recursive = symlink.recursive;
            }
        )
        cfg.symlinks)
      // lib.mapAttrs' (
        name: script:
          lib.nameValuePair "theme-switcher/hooks/theme-set.d/${name}" {
            text = ''
              #!/bin/sh
              set -euo pipefail
              ${script}
            '';
            executable = true;
          }
      )
      afterHooks // cfg.afterHooks;

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

        ${scripts.exportGsettingsSchemas}
        export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

        THEMES_DIR="${themesDir}"
        CURRENT="${currentLink}"
        CURRENT_BG="${themesDir}/current-background"

        THEME=$(ls -1 "$THEMES_DIR" | grep -v -E '^(current|current-background)$' | sort | ${cfg.selectorCommand} 2>/dev/null || echo "")

        if [ -z "$THEME" ] || [ ! -d "$THEMES_DIR/$THEME" ]; then
          exit 0
        fi

        ln -sfn "$THEMES_DIR/$THEME" "$CURRENT"

        ${scripts.applyGtkConfig}
        ${scripts.selectBackground {preserveCurrentBg = true;}}

        HOOK_DIR="$HOME/.config/theme-switcher/hooks/theme-set.d"
        if [ -d "$HOOK_DIR" ]; then
          for hook in "$HOOK_DIR"/*; do
            [ -x "$hook" ] && "$hook" "$THEME"
          done
        fi
        if [ -x "$HOME/.config/theme-switcher/hooks/theme-set" ]; then
          "$HOME/.config/theme-switcher/hooks/theme-set" "$THEME"
        fi
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
