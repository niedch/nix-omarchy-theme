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
  rendered =
    if hasColors
    then lib.mapAttrs (n: t: render.renderTemplate colors t) templates
    else {};
  stripTpl = n: let
    m = builtins.match "(.+)\.tpl" n;
  in
    if m != null then builtins.head m else n;

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
        if [ ! -f "$out/${lib.escapeShellArg n}" ]; then
          cp "${filePath}" "$out/${lib.escapeShellArg n}"
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

        GTK_THEME="Adwaita-dark"
        PREFER_DARK="1"
        if [ -f "$out/light.mode" ]; then
          GTK_THEME="Adwaita"
          PREFER_DARK="0"
        fi

        GTK_THEME=$(cat "$out/gtk.theme" 2>/dev/null || echo "Yaru-blue")
        ICON_THEME=$(cat "$out/icons.theme" 2>/dev/null || echo "Adwaita")

        for version in 3.0 4.0; do
          cat > "$out/settings-$version.ini" << EOF
    [Settings]
    gtk-theme-name=$GTK_THEME
    gtk-application-prefer-dark-theme=$PREFER_DARK
    gtk-icon-theme-name=$ICON_THEME
    EOF
        done
  ''
