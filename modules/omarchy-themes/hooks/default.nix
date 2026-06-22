{
  "01_apply_gtk" = ''
    CURRENT="''${CURRENT:-$HOME/.local/share/themes/current}"
    GTK_THEME=$(cat "$CURRENT/gtk.theme")
    ICON_THEME=$(cat "$CURRENT/icons.theme")
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme \
      "$([ -f "$CURRENT/light.mode" ] && echo "prefer-light" || echo "prefer-dark")" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
  '';
  "02_apply_chromium_color" = ''
    CURRENT="''${CURRENT:-$HOME/.local/share/themes/current}"
    if [ -f "$CURRENT/chromium-color.json" ]; then
      for policy_dir in \
        "$HOME/.config/chromium/Policies/managed" \
        "$HOME/.config/chromium/policies/managed"; do
          mkdir -p "$policy_dir"
          cp "$CURRENT/chromium-color.json" "$policy_dir/color.json"
      done
    fi
  '';
  "03_reload_defaults" = ''
    [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && hyprctl reload >/dev/null 2>&1 || true

    makoctl reload 2>/dev/null || true
    obsidian-cli eval "code=document.location.reload()" 2>/dev/null || true

    systemctl --user restart elephant.service walker.service swaybg.service waybar.service 2>/dev/null || true

    pkill -USR2 ghostty 2>/dev/null || true
    pkill -SIGUSR2 btop 2>/dev/null || true
    pkill -USR2 opencode 2>/dev/null || true
    pkill -SIGUSR1 nvim 2>/dev/null || true
  '';
  "90_restart_nautilus" = ''
    nautilus -q 2>/dev/null || true
  '';
  "95_notify" = ''
    notify-send "Theme Switched" "$1" -i preferences-desktop-theme 2>/dev/null || true
  '';
}
