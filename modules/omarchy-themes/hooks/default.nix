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

  "02_reload_defaults" = ''
    [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && hyprctl reload >/dev/null 2>&1 || true
    pkill -USR2 ghostty 2>/dev/null || true
    makoctl reload 2>/dev/null || true

    obsidian-cli eval "code=document.location.reload()" 2>/dev/null || true

    systemctl --user restart elephant.service walker.service swaybg.service waybar.service 2>/dev/null || true

    pkill -SIGUSR2 btop 2>/dev/null || true
    pkill -USR2 opencode 2>/dev/null || true
    pkill -SIGUSR1 nvim 2>/dev/null || true
    find /tmp -type s \( -name '0' -path '*/nvim*' -o -name '*nvim*' \) 2>/dev/null -exec nvim --server {} --remote-send '<C-\><C-N>:source $MYVIMRC<CR>' \; 2>/dev/null || true
  '';
  "90_restart_nautilus" = ''
    nautilus -q 2>/dev/null || true
  '';
  "95_notify" = ''
    notify-send "Theme Switched" "$1" -i preferences-desktop-theme 2>/dev/null || true
  '';
}
