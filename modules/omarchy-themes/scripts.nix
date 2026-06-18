{pkgs}: let
  gsettings = "${pkgs.glib.bin}/bin/gsettings";
  schemasDir = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${pkgs.gsettings-desktop-schemas.version}/glib-2.0/schemas";
in {
  applyGtkConfig = ''
    if [ -f "$CURRENT/gtk.theme" ]; then
      GTK_THEME=$(cat "$CURRENT/gtk.theme")
    elif [ -f "$CURRENT/light.mode" ]; then
      GTK_THEME="Adwaita"
    else
      GTK_THEME="Adwaita-dark"
    fi
    ${gsettings} set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    ${gsettings} set org.gnome.desktop.interface color-scheme \
      "$([ -f "$CURRENT/light.mode" ] && echo "prefer-light" || echo "prefer-dark")" 2>/dev/null || true
    ICON_THEME=$(cat "$CURRENT/icons.theme" 2>/dev/null || echo "Adwaita")
    ${gsettings} set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    ln -sfn "$CURRENT/settings-3.0.ini" "$HOME/.config/gtk-3.0/settings.ini"
    ln -sfn "$CURRENT/settings-4.0.ini" "$HOME/.config/gtk-4.0/settings.ini"
  '';

  applyChromiumColor = ''
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
  '';

  selectBackground = {preserveCurrentBg ? false}: let
    linkSnippet =
      if preserveCurrentBg
      then ''
        PREV_BG=$(readlink "$CURRENT_BG" 2>/dev/null || echo "")
        PREV_BG_NAME=$(basename "$PREV_BG" 2>/dev/null || echo "")
        if [ -n "$PREV_BG_NAME" ] && [ -f "$CURRENT/backgrounds/$PREV_BG_NAME" ]; then
          ln -sfn "$CURRENT/backgrounds/$PREV_BG_NAME" "$CURRENT_BG"
        else
          ln -sfn "$CURRENT/backgrounds/$FIRST_BG" "$CURRENT_BG"
        fi
      ''
      else ''
        ln -sfn "$CURRENT/backgrounds/$FIRST_BG" "$CURRENT_BG"
      '';
  in ''
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
      ${linkSnippet}
    fi
  '';

  exportGsettingsSchemas = ''
    export GSETTINGS_SCHEMA_DIR="${schemasDir}"
  '';
}
