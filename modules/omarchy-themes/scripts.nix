{pkgs}: {
  applyChromiumColor = ''
        THEME_HEX="#1c2027"
        if [ -f "$CURRENT/light.mode" ]; then
          THEME_HEX="#eff1f5"
        fi
        if [ -f "$CURRENT/chromium.theme" ]; then
          CHROMIUM_RGB=$(cat "$CURRENT/chromium.theme")
          THEME_HEX=$(printf '#%02x%02x%02x' $(echo "$CHROMIUM_RGB" | tr ',' ' ') 2>/dev/null || echo "$THEME_HEX")
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

}
