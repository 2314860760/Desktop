#!/bin/bash
# 预览/VNC 服务启动脚本(KasmVNC 版)
# 与旧版差异：不再使用 tigervnc + websockify + noVNC，
# 直接由 KasmVNC 的 Xkasmvnc 提供 X server 与浏览器客户端(同一端口)。

# 关闭桌面空闲锁屏(CNB 平台占用 SSH，锁屏后用户无法自救)
NOLOCK_LIB="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/NoLock.sh"
if [ -f "$NOLOCK_LIB" ]; then . "$NOLOCK_LIB"; else disable_screen_lock() { :; }; fi

set -euo pipefail

# 兜底：桌面拉起时确保模型网关与管理页在跑（Installer.sh 未执行时也能工作），
# 后台执行，失败不影响桌面；管理员/普通用户共用同一个回环端口
if [ "$(id -u)" = "0" ]; then
  MB_FALLBACK=/opt/youjingsenlin/ModelBridge.sh
  [ -x "$MB_FALLBACK" ] || MB_FALLBACK=/workspace/Installer/ModelBridge.sh
  [ -r "$MB_FALLBACK" ] && ( bash "$MB_FALLBACK" start >/dev/null 2>&1 || true ) &
  [ -x /opt/youjingsenlin/ModelBridgeAdmin.sh ] && ( bash /opt/youjingsenlin/ModelBridgeAdmin.sh start >/dev/null 2>&1 || true ) &
fi

VNC_DISPLAY="${VNC_DISPLAY:-:2}"
VNC_PORT="${VNC_PORT:-5902}"
# 浏览器直连端口；沿用旧变量名 NOVNC_PORT 以兼容既有配置
WEB_PORT="${WEB_PORT:-${NOVNC_PORT:-8686}}"
KASM_WEB_DIR="${KASM_WEB_DIR:-/usr/share/kasmvnc/www}"
KASM_BIN="${KASM_BIN:-/usr/bin/Xkasmvnc}"
KASM_BIND="${KASM_BIND:-0.0.0.0}"
VNC_USER="${VNC_USER:-user}"
VNC_HOME="${VNC_HOME:-/home/${VNC_USER}}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
VNC_DEPTH="${VNC_DEPTH:-24}"
CNB_BRANCH_NAME="${CNB_BRANCH:-}"

resolve_desktop_session() {
  case "${CNB_BRANCH_NAME}" in
    LXQT)
      echo "lxqt"
      ;;
    LXDE)
      echo "lxde"
      ;;
    XFace)
      echo "xfce4"
      ;;
    Mate)
      echo "mate"
      ;;
    Gnome)
      echo "gnome"
      ;;
    Cinnamon)
      echo "cinnamon"
      ;;
    Openbox)
      echo "openbox"
      ;;
    Other)
      echo "other"
      ;;
    ""|KDE|GPU|main|master)
      echo "plasma"
      ;;
    *)
      echo "plasma"
      ;;
  esac
}

resolve_startup_command() {
  case "${DESKTOP_SESSION}" in
    plasma|kde)
      echo "startplasma-x11"
      ;;
    lxqt)
      echo "startlxqt"
      ;;
    lxde)
      echo "startlxde"
      ;;
    xfce|xfce4|xface)
      echo "startxfce4"
      ;;
    mate)
      echo "mate-session"
      ;;
    gnome)
      echo "gnome-session"
      ;;
    cinnamon)
      echo "cinnamon-session"
      ;;
    openbox)
      echo "openbox"
      ;;
    other|xterm)
      echo "xterm -geometry 80x24+10+10 -ls"
      ;;
    *)
      echo "Unsupported DESKTOP_SESSION: ${DESKTOP_SESSION}" >&2
      exit 1
      ;;
  esac
}

# 显式写一份 xstartup。
# 不能依赖镜像自带的 xstartup：Debian 上 TigerVNC 的默认会话走
# /usr/bin/x-session-manager，而 xfce4-session 的 alternatives 优先级(50) 高于
# startplasma-x11(40)，自动模式会选到 XFCE —— 这正是"分支是 KDE 却开了 XFCE"的原因。
# 只有现有 xstartup 已经明确指定了目标桌面时才保留。
ensure_xstartup() {
  local startup_command xs
  startup_command="$(resolve_startup_command)"
  xs="${VNC_HOME}/.vnc/xstartup"

  install -d -m 700 "${VNC_HOME}/.vnc"

  # 顺手关掉该用户的空闲锁屏/屏保/DPMS
  disable_screen_lock "${VNC_USER}" "${VNC_HOME}"

  if [ -f "${xs}" ] && grep -qF "${startup_command%% *}" "${xs}" && ! grep -q 'xinitrc' "${xs}"; then
    : # 已是目标桌面的显式启动，保留
  else
    cat > "${xs}" <<EOF
#!/bin/sh
# 由 Installer/Preview.sh 生成：显式拉起 ${DESKTOP_SESSION}，
# 避免走 /usr/bin/x-session-manager 的 alternatives 默认值(那里 XFCE 优先级更高)
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# 关闭 X 层屏保与显示省电：会话空闲后不黑屏、不锁屏
xset s off >/dev/null 2>&1
xset s noblank >/dev/null 2>&1
xset -dpms >/dev/null 2>&1
# 兜底：桌面起来 20 秒后清理一次残留的锁屏进程(以防某个桌面仍按自己的策略拉起)
(
  sleep 20
  for pid in \$(pgrep -u "\$(id -u)" -f '^(/usr/bin/|/usr/libexec/|/usr/lib/[^/]+/)?(light-locker|xscreensaver|xfce4-screensaver|mate-screensaver|cinnamon-screensaver)' 2>/dev/null); do
    kill "\$pid" 2>/dev/null
  done
) >/dev/null 2>&1 &
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session -- ${startup_command}
fi
exec ${startup_command}
EOF
  fi

  chmod 755 "${xs}"
  chown -R "${VNC_USER}:${VNC_USER}" "${VNC_HOME}/.vnc"
}

kill_stale_vnc_session() {
  local num
  num="${VNC_DISPLAY#:}"
  # 末尾留空格，避免 :20 之类的误匹配
  pkill -f "Xkasmvnc ${VNC_DISPLAY} " >/dev/null 2>&1 || true
  sleep 1
  rm -f "/tmp/.X${num}-lock"
  rm -f "/tmp/.X11-unix/X${num}"
}

start_preview_services() {
  local num log
  num="${VNC_DISPLAY#:}"
  log="${VNC_HOME}/.vnc/kasmvnc.log"

  # KasmVNC 的 X server：-httpd 指向自带 web 客户端，web 与 websocket 共用 -websocketPort
  sudo -u "${VNC_USER}" bash -c "setsid '${KASM_BIN}' '${VNC_DISPLAY}' \
    -geometry '${VNC_GEOMETRY}' -depth '${VNC_DEPTH}' \
    -SecurityTypes None -sslOnly 0 -disableBasicAuth -ac \
    -interface '${KASM_BIND}' \
    -websocketPort '${WEB_PORT}' -rfbport '${VNC_PORT}' \
    -httpd '${KASM_WEB_DIR}' >'${log}' 2>&1 &"

  # 等 X socket 就绪再拉起桌面，避免会话进程抢跑
  for _ in $(seq 1 50); do
    [ -S "/tmp/.X11-unix/X${num}" ] && break
    sleep 0.2
  done

  sudo -u "${VNC_USER}" env DISPLAY="${VNC_DISPLAY}" HOME="${VNC_HOME}" \
    setsid bash "${VNC_HOME}/.vnc/xstartup" >>"${log}" 2>&1 &

  echo "KasmVNC: display ${VNC_DISPLAY} -> http://${KASM_BIND}:${WEB_PORT}/"
}

DESKTOP_SESSION="${DESKTOP_SESSION:-$(resolve_desktop_session)}"

ensure_xstartup
kill_stale_vnc_session
start_preview_services
