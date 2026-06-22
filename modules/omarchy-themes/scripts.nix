{pkgs}: {
  applyChromiumColor = ''
      if [ -f "$CURRENT/chromium-color.json" ]; then
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
          cp "$CURRENT/chromium-color.json" "$policy_dir/color.json"
        done
      fi
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
