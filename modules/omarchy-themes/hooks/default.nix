{
  "0_reload_defaults" = ''
    hyprctl reload 2>/dev/null || true
    pkill -USR2 ghostty 2>/dev/null || true
    makoctl reload 2>/dev/null || true

    obsidian-cli eval "code=document.location.reload()" 2>/dev/null || true

    systemctl --user restart elephant.service walker.service swaybg.service waybar.service 2>/dev/null || true

    pkill -SIGUSR2 btop 2>/dev/null || true
    pkill -USR2 opencode 2>/dev/null || true
  '';
  "90_restart_nautilus" = ''
    nautilus -q 2>/dev/null || true
  '';
  "100_notify" = ''
    notify-send "Theme Switched" "$1" -i preferences-desktop-theme
  '';
}
