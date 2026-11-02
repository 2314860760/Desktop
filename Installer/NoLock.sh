#!/bin/bash
# 关闭各桌面环境的"空闲自动锁屏 / 屏保 / DPMS 黑屏"
#
# 背景：CNB 平台默认占用 SSH 连接与 root 密码。用户如果没改过 root 密码，
# 桌面被空闲锁屏挡住后既进不去桌面、也没法用 SSH 进去解锁，只能重启环境。
# 所以这里把各桌面的自动锁定、屏保、显示省电统一关掉。
#
# 用法（由 Start.sh / Preview.sh source 后调用）：
#   disable_screen_lock <用户> <家目录>
#
# 覆盖范围：KDE Plasma、XFCE、LXQt、LXDE、MATE、Cinnamon、GNOME，
# 以及 light-locker / xscreensaver / xfce4-screensaver 这类外挂锁屏程序。
# 所有设置都做了存在性判断，缺失的命令或配置项直接跳过，不会中断桌面启动。

# 以目标用户身份执行命令（root 会话直接执行）
_nolock_as() {
  local user="$1" home="$2"
  shift 2
  if [ "$(id -u)" = 0 ] && [ "$user" != root ] && command -v sudo >/dev/null 2>&1; then
    sudo -u "$user" env HOME="$home" "$@"
  else
    env HOME="$home" "$@"
  fi
}

# 写一个"禁用某锁屏程序自启动"的 XDG autostart 覆盖项
# XDG 规则里同名且 Hidden=true 的项会覆盖 /etc/xdg/autostart 里的原件
_nolock_autostart() {
  local home="$1" name="$2"
  cat >"$home/.config/autostart/$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name (disabled)
Comment=由 Installer/NoLock.sh 生成：禁用空闲锁屏
Exec=true
NoDisplay=true
Hidden=true
EOF
}

# 批量设置 gsettings（每行一条: schema key value），失败的项直接忽略
_nolock_gsettings() {
  local user="$1" home="$2" cmds="" s k v
  command -v gsettings >/dev/null 2>&1 || return 0
  while read -r s k v; do
    [ -n "$s" ] || continue
    cmds="$cmds gsettings set $s $k $v >/dev/null 2>&1 || true;"
  done
  [ -n "$cmds" ] || return 0
  if command -v dbus-run-session >/dev/null 2>&1; then
    _nolock_as "$user" "$home" dbus-run-session -- bash -c "$cmds" >/dev/null 2>&1 || true
  else
    _nolock_as "$user" "$home" bash -c "$cmds" >/dev/null 2>&1 || true
  fi
}

# 参数: 用户 家目录
disable_screen_lock() {
  local user="${1:-}" home="${2:-}"
  [ -n "$user" ] && [ -n "$home" ] || return 0
  [ -d "$home" ] || return 0

  install -d -m 755 "$home/.config/autostart" 2>/dev/null || true

  # 1) 通用：屏蔽外挂锁屏程序的自动启动
  local l
  for l in light-locker xscreensaver xfce4-screensaver xfce4-screensaver-preferences \
           mate-screensaver gnome-screensaver cinnamon-screensaver; do
    _nolock_autostart "$home" "$l" 2>/dev/null || true
  done

  # 2) KDE Plasma：kscreenlocker 不开自动锁，powerdevil 不做空闲关屏/挂起
  cat >"$home/.config/kscreenlockerrc" <<'EOF'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF

  # Plasma 6
  cat >"$home/.config/powerdevilrc" <<'EOF'
[AC][Display]
DimDisplayWhenIdle=false
DimDisplayIdleTimeoutSec=0
TurnOffDisplayWhenIdle=false
TurnOffDisplayIdleTimeoutSec=0

[AC][SuspendSession]
SuspendType=0
EOF

  # Plasma 5
  cat >"$home/.config/powermanagementprofilesrc" <<'EOF'
[AC][DimDisplay]
idleTime=0

[AC][DPMSControl]
idleTime=0
lockBeforeSleep=false
EOF

  # 3) XFCE：会话不锁屏 + 电源管理不黑屏 + screensaver 全关
  install -d -m 755 "$home/.config/xfce4/xfconf/xfce-perchannel-xml" 2>/dev/null || true
  cat >"$home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="shutdown" type="empty">
    <property name="LockScreen" type="bool" value="false"/>
  </property>
</channel>
EOF
  cat >"$home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="inactivity-on-ac" type="uint" value="0"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
  </property>
</channel>
EOF
  cat >"$home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="idle-activation" type="empty">
      <property name="enabled" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF

  # 4) LXDE / 通用 xscreensaver：不锁、不超时、不开 DPMS
  cat >"$home/.xscreensaver" <<'EOF'
mode: off
timeout: 0:00:00
cycle: 0:00:00
lock: False
lockTimeout: 0:00:00
dpmsEnabled: False
dpmsStandby: 0:00:00
dpmsSuspend: 0:00:00
dpmsOff: 0:00:00
EOF

  # 5) LXQt：电源管理不做空闲动作（keys 不存在时会被忽略）
  install -d -m 755 "$home/.config/lxqt" 2>/dev/null || true
  cat >"$home/.config/lxqt/powermanagement.conf" <<'EOF'
[General]
idlenessTimeSecs=0
turnOffMonitorsWhenIdle=false
suspendWhenIdle=false
hibernateWhenIdle=false
lockWhenIdle=false
EOF

  # 6) MATE / Cinnamon / GNOME：gsettings 里关掉屏保与空闲挂起
  _nolock_gsettings "$user" "$home" <<'EOF'
org.mate.screensaver lock-enabled false
org.mate.screensaver idle-activation-enabled false
org.mate.power-manager sleep-display-ac 0
org.mate.power-manager sleep-computer-ac 0
org.mate.power-manager blank-screen-ac false
org.cinnamon.desktop.screensaver lock-enabled false
org.cinnamon.desktop.screensaver idle-activation-enabled false
org.cinnamon.desktop.session idle-delay 0
org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type nothing
org.cinnamon.settings-daemon.plugins.power idle-dim false
org.gnome.desktop.screensaver lock-enabled false
org.gnome.desktop.screensaver idle-activation-enabled false
org.gnome.desktop.session idle-delay 0
org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
EOF

  chown -R "$user":"$user" "$home/.config" 2>/dev/null || true
  chown "$user":"$user" "$home/.xscreensaver" 2>/dev/null || true
  echo "[锁屏] 已关闭 $user($home) 的空闲锁屏与熄屏"
}
