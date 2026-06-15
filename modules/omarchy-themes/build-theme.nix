{ lib, pkgs, render }:
{ name, theme, templates, cursorThemeName, cursorThemeSize }:
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
    lib.mapAttrs (n: t: render.renderTemplate colors t) templates
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
  settingsGtk3Ini = pkgs.writeText "settings-gtk3-${name}.ini" ''
    [Settings]
    gtk-theme-name=${gtkThemeName}
    gtk-cursor-theme-name=${cursorThemeName}
    gtk-cursor-theme-size=${toString cursorThemeSize}
    gtk-application-prefer-dark-theme=${if isLight then "0" else "1"}
  '';
  settingsGtk4Ini = pkgs.writeText "settings-gtk4-${name}.ini" ''
    [Settings]
    gtk-theme-name=${gtkThemeName}
    gtk-cursor-theme-name=${cursorThemeName}
    gtk-cursor-theme-size=${toString cursorThemeSize}
    gtk-application-prefer-dark-theme=${if isLight then "0" else "1"}
    color-scheme=${colorScheme}
  '';
in
pkgs.runCommandLocal "omarchy-theme-${name}" { } ''
  mkdir -p "$out"

  cp -r ${themeRoot}/* "$out/"

  rm -rf "$out/.git" 2>/dev/null || true

  ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: filePath: ''
    if [ ! -f "$out/${lib.escapeShellArg n}" ]; then
      cp "${filePath}" "$out/${lib.escapeShellArg n}"
    fi
  '') renderedFiles)}

  cp "${settingsGtk3Ini}" "$out/settings-gtk3.ini"
  cp "${settingsGtk4Ini}" "$out/settings-gtk4.ini"

  ${lib.optionalString (theme?defaultBackground && theme.defaultBackground != null) ''
    echo "${theme.defaultBackground}" > "$out/default-background"
  ''}
''
