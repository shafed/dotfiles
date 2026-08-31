local terminal = "kitty"

hl.on("hyprland.start", function()
  hl.exec_cmd(terminal)
  hl.exec_cmd("hyprpaper")
  -- Sync the wallpaper to the current darkman state on every Hyprland start:
  -- darkman.service usually outlives a Hyprland reload, so it won't refire
  -- its hooks just because hyprpaper restarted.
  hl.exec_cmd("$HOME/.local/share/darkman/wallpaper \"$(darkman get)\"")
  hl.exec_cmd("hyprland-per-window-layout")
  -- OpenWhispr keeps its session token encrypted with a master key in the OS
  -- keyring (KWallet here), so Secret Service must be up before it starts, or
  -- it falls back to the login screen on every boot. org.freedesktop.secrets
  -- is not itself D-Bus-activatable — only org.kde.secretservicecompat is, and
  -- ksecretd registers the former only once started under that name. pam_kwallet5
  -- can't help here: tty1 autologins via agetty --autologin, so PAM never sees a
  -- password to hand to kwalletd. The wallet password is empty instead, so no
  -- unlock prompt is needed once ksecretd is up.
  hl.exec_cmd(
    "busctl --user call org.freedesktop.DBus /org/freedesktop/DBus "
      .. "org.freedesktop.DBus StartServiceByName su org.kde.secretservicecompat 0 "
      .. "&& openwhispr"
  )
  hl.exec_cmd("hypridle")
  hl.exec_cmd("hyprsunset")
  hl.exec_cmd(
    "systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP "
      .. "&& systemctl --user restart adrop.service"
  )
end)
