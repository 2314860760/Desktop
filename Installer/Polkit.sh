#!/bin/bash
# 修复容器内 pkexec / polkit 提权失败
#
# 现象：桌面里执行需要 root 的操作时报
#   Error checking for authorization org.freedesktop.policykit.exec:
#   GDBus.Error:org.freedesktop.policykit1.Error.Failed: Process not found
#
# 原因：容器里没有 systemd-logind，polkitd 无法把调用进程关联到"登录会话"，
#       加上容器内一般没有常驻的 polkit 认证代理，pkexec 就会卡在鉴权阶段直接失败。
#
# 处理（由 Installer.sh / Start.sh 调用，幂等）：
#   1) 确保系统总线与 polkitd 在跑
#   2) 写一条放行规则：本机用户发起的 action 直接 YES，不再等弹窗认证
#   3) 给 user / root 配置 sudo 免密：优先尝试 sudo 的程序(如 lxqt-sudo)不会再落到 pkexec
#
# 副作用：容器内 `user` 与 `root` 可以免密 sudo。环境本身是随时可丢弃的沙箱，
#         默认密码也是公开的；如果需要恢复校验，删掉下面两个文件即可：
#           /etc/sudoers.d/90-clouddesktop
#           /etc/polkit-1/rules.d/49-clouddesktop.rules

# 系统总线没起来的话先拉起来（polkitd 依赖 dbus system bus）
_polkit_start_dbus() {
  [ -S /run/dbus/system_bus_socket ] && return 0
  command -v service >/dev/null 2>&1 || return 0
  service dbus start >/dev/null 2>&1 || true
}

# 启动 polkitd（没有 systemd 时直接起进程）
_polkit_start_daemon() {
  pgrep -x polkitd >/dev/null 2>&1 && return 0
  local b
  for b in /usr/lib/polkit-1/polkitd /usr/libexec/polkitd; do
    [ -x "$b" ] || continue
    setsid "$b" --no-debug >>/var/log/polkitd.log 2>&1 &
    sleep 1
    pgrep -x polkitd >/dev/null 2>&1 && return 0
  done
  # 兜底：让 init 脚本试一次
  if command -v service >/dev/null 2>&1; then
    service polkit start >/dev/null 2>&1 || service polkitd start >/dev/null 2>&1 || true
  fi
  return 0
}

# 放行规则：本机用户不用走图形认证
_polkit_write_rules() {
  local dir=/etc/polkit-1/rules.d f=/etc/polkit-1/rules.d/49-clouddesktop.rules
  install -d -m 750 "$dir" 2>/dev/null || return 0
  cat >"$f" <<'EOF'
// 由 Installer/Polkit.sh 生成：容器内没有 logind，也没有常驻认证代理，
// 让桌面用户(以及 root / sudo 组)发起的提权请求直接通过，避免 pkexec 报 Process not found。
polkit.addRule(function (action, subject) {
  if (subject.user == "root" || subject.user == "user" || subject.isInGroup("sudo")) {
    return polkit.Result.YES;
  }
});
EOF
  chmod 644 "$f" 2>/dev/null || true
}

# sudo 免密：避免没有 tty、没有图形 askpass 时反复回落到 pkexec
_polkit_write_sudoers() {
  local f=/etc/sudoers.d/90-clouddesktop tmp
  [ -d /etc/sudoers.d ] || return 0
  tmp="$(mktemp)" || return 0
  cat >"$tmp" <<'EOF'
# 由 Installer/Polkit.sh 生成：容器内没有 tty 也没有图形 askpass，
# 免密是为了让 lxqt-sudo / gksu 这类程序不再回落到 pkexec。
Defaults:user !requiretty
user ALL=(ALL) NOPASSWD: ALL
root ALL=(ALL) NOPASSWD: ALL
EOF
  if command -v visudo >/dev/null 2>&1 && ! visudo -cf "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 1
  fi
  install -m 0440 -o root -g root "$tmp" "$f" 2>/dev/null || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

polkit_setup() {
  [ "$(id -u)" = 0 ] || return 0
  _polkit_start_dbus
  _polkit_start_daemon
  _polkit_write_rules
  _polkit_write_sudoers
  echo "[提权] polkit 已放行本机用户，sudo 已配置免密(user/root)"
}
