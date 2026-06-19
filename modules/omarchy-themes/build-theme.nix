{
  lib,
  pkgs,
  render,
}: {
  name,
  theme,
  templates,
}: let
  themeSrc = pkgs.fetchgit {
    url = theme.url;
    rev = theme.ref;
    hash = theme.hash;
  };
  themeRoot = "${themeSrc}/${theme.subpath}";
  colorsFile = "${themeRoot}/colors.toml";
  hasColors = builtins.pathExists colorsFile;
  colors =
    if hasColors
    then builtins.fromTOML (builtins.readFile colorsFile)
    else {};
  gtkMetadata = let
    hasLightMode = builtins.pathExists "${themeRoot}/light.mode";
    preferDark =
      if hasLightMode
      then "0"
      else "1";
    defaultGtkTheme =
      if hasLightMode
      then "Adwaita"
      else "Adwaita-dark";
    gtkThemeFile = "${themeRoot}/gtk.theme";
    iconsThemeFile = "${themeRoot}/icons.theme";
  in {
    prefer_dark = preferDark;
    gtk_theme =
      if builtins.pathExists gtkThemeFile
      then lib.strings.removeSuffix "\n" (builtins.readFile gtkThemeFile)
      else defaultGtkTheme;
    icon_theme =
      if builtins.pathExists iconsThemeFile
      then lib.strings.removeSuffix "\n" (builtins.readFile iconsThemeFile)
      else "Adwaita";
  };
  renderContext = colors // gtkMetadata;
  rendered = lib.mapAttrs (n: t: render.renderTemplate renderContext t) (
    if hasColors
    then templates
    else lib.filterAttrs (n: _: lib.hasPrefix "settings-" n || n == "gtk.theme.tpl" || n == "icons.theme.tpl") templates
  );
  stripTpl = n: let
    m = builtins.match "(.+)\.tpl" n;
  in
    if m != null
    then builtins.head m
    else n;

  renderedFiles =
    lib.mapAttrs' (
      n: content:
        lib.nameValuePair (stripTpl n) (pkgs.writeText "omarchy-${name}-${n}" content)
    )
    rendered;
in
  pkgs.runCommandLocal "omarchy-theme-${name}" {} ''
    mkdir -p "$out"
    cp -r ${themeRoot}/* "$out/"
    chmod -R u+w "$out"
    rm -rf "$out/.git" 2>/dev/null || true

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: filePath: ''
        outFile="$out/${lib.escapeShellArg n}"
        if [ ! -f "$outFile" ]; then
          mkdir -p "$(dirname "$outFile")"
          cp "${filePath}" "$outFile"
        fi
      '')
      renderedFiles)}

    ${lib.optionalString (theme?defaultBackground && theme.defaultBackground != null) ''
      echo "${theme.defaultBackground}" > "$out/default-background"
    ''}

    ${lib.concatStringsSep "\n" (builtins.map (bg: let
      fname =
        if bg.filename != null
        then bg.filename
        else builtins.baseNameOf bg.url;
      fetched = pkgs.fetchurl {
        url = bg.url;
        hash = bg.hash;
      };
    in ''
      mkdir -p "$out/backgrounds"
      cp ${fetched} "$out/backgrounds/${lib.escapeShellArg fname}"
    '') (theme.extraBackgrounds or []))}
  ''
