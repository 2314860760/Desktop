#!/bin/bash

set -euo pipefail

VNC_DISPLAY="${VNC_DISPLAY:-:2}"
VNC_PORT="${VNC_PORT:-5902}"
NOVNC_PORT="${NOVNC_PORT:-8686}"
NOVNC_WEB_DIR="${NOVNC_WEB_DIR:-/usr/share/novnc}"
VNC_USER="${VNC_USER:-user}"
VNC_HOME="${VNC_HOME:-/home/${VNC_USER}}"
VNC_CONFIG_DIR="${VNC_CONFIG_DIR:-${VNC_HOME}/.config/tigervnc}"
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

DESKTOP_SESSION="${DESKTOP_SESSION:-$(resolve_desktop_session)}"

configure_desktop_session() {
  local startup_command

  case "${DESKTOP_SESSION}" in
    plasma|kde)
      startup_command="startplasma-x11"
      ;;
    lxqt)
      startup_command="startlxqt"
      ;;
    lxde)
      startup_command="startlxde"
      ;;
    xfce|xfce4|xface)
      startup_command="startxfce4"
      ;;
    mate)
      startup_command="mate-session"
      ;;
    gnome)
      startup_command="gnome-session"
      ;;
    cinnamon)
      startup_command="cinnamon-session"
      ;;
    openbox)
      startup_command="openbox"
      ;;
    other|xterm)
      startup_command="xterm -geometry 80x24+10+10 -ls"
      ;;
    *)
      echo "Unsupported DESKTOP_SESSION: ${DESKTOP_SESSION}" >&2
      exit 1
      ;;
  esac

  for xstartup in /root/.vnc/xstartup "${VNC_HOME}/.vnc/xstartup"; do
    if [ -f "${xstartup}" ]; then
      sed -i "s|startplasma-x11|${startup_command}|" "${xstartup}"
    fi
  done
}

setup_vnc_config() {
  install -d -m 700 "${VNC_HOME}/.vnc"
  install -d -m 700 "${VNC_CONFIG_DIR}"

  cat > "${VNC_CONFIG_DIR}/config" <<EOF
securitytypes=None
localhost=yes
EOF

  rm -f "${VNC_HOME}/.vnc/passwd" "${VNC_CONFIG_DIR}/passwd"
  chown -R "${VNC_USER}:${VNC_USER}" "${VNC_HOME}/.vnc" "${VNC_CONFIG_DIR}"
}

kill_stale_vnc_session() {
  sudo -u "${VNC_USER}" vncserver -kill "${VNC_DISPLAY}" >/dev/null 2>&1 || true
  rm -f /tmp/.X$(printf '%s' "${VNC_DISPLAY}" | tr -d ':')-lock
  rm -f "/tmp/.X11-unix/X$(printf '%s' "${VNC_DISPLAY}" | tr -d ':')"
}

start_preview_services() {
  sudo -u "${VNC_USER}" vncserver "${VNC_DISPLAY}" -SecurityTypes None -localhost yes
  pkill -f "websockify.* ${NOVNC_PORT} " >/dev/null 2>&1 || true
  websockify -D --web="${NOVNC_WEB_DIR}" "${NOVNC_PORT}" "localhost:${VNC_PORT}"
}

configure_desktop_session
setup_vnc_config
kill_stale_vnc_session
start_preview_services
