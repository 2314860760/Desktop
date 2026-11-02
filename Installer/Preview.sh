#!/bin/bash
# 预览/VNC 服务启动脚本(KasmVNC 版)
# 与旧版差异：不再使用 tigervnc + websockify + noVNC，
# 直接由 KasmVNC 的 Xkasmvnc 提供 X server 与浏览器客户端(同一端口)。

set -euo pipefail

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

# 优先复用镜像内已有的 xstartup(与 TigerVNC 时期行为一致)；
# 缺失时从 root 复制，再缺失才生成一份带 dbus 的最小版本。
ensure_xstartup() {
  local startup_command xs
  startup_command="$(resolve_startup_command)"
  xs="${VNC_HOME}/.vnc/xstartup"

  install -d -m 700 "${VNC_HOME}/.vnc"

  if [ -f "${xs}" ]; then
    sed -i "s|startplasma-x11|${startup_command}|" "${xs}"
  elif [ -f /root/.vnc/xstartup ]; then
    cp /root/.vnc/xstartup "${xs}"
    sed -i "s|startplasma-x11|${startup_command}|" "${xs}"
  else
    cat > "${xs}" <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session ${startup_command}
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
