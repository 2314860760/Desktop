#/bin/bash
# 启动云桌面(KasmVNC 版)
# 每个会话由独立的 Xkasmvnc 进程提供：X server + 浏览器客户端共用同一个端口

KASM_WEB_DIR="${KASM_WEB_DIR:-/usr/share/kasmvnc/www}"
KASM_BIN="${KASM_BIN:-/usr/bin/Xkasmvnc}"
KASM_BIND="${KASM_BIND:-0.0.0.0}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
VNC_DEPTH="${VNC_DEPTH:-24}"
# 默认桌面会话；需要别的桌面时用 DESKTOP_CMD=startlxqt 之类覆盖
DESKTOP_CMD="${DESKTOP_CMD:-startplasma-x11}"

echo "      你好，世界！正在启动云桌面~"
echo "      这可能需要1分钟"
echo ""

# 显式写一份 xstartup(参数: 用户 家目录 会话命令)。
# 镜像自带的 xstartup 会走 /usr/bin/x-session-manager，而那里 XFCE 的
# alternatives 优先级(50) 高于 startplasma-x11(40)，会错误地开出 XFCE 桌面。
ensure_xstartup() {
  local owner="$1" home="$2" cmd="$3" xs
  xs="${home}/.vnc/xstartup"

  install -d -m 700 "${home}/.vnc"

  cat > "${xs}" <<EOF
#!/bin/sh
# 由 Installer/Start.sh 生成：显式拉起目标桌面，不走 x-session-manager
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session -- ${cmd}
fi
exec ${cmd}
EOF

  chmod 755 "${xs}"
  chown -R "${owner}:${owner}" "${home}/.vnc"
}

# 参数: 显示号 web端口 rfb端口 用户 家目录
start_session() {
  local display="$1" web_port="$2" rfb_port="$3" owner="$4" home="$5"
  local num log
  num="${display#:}"
  log="${home}/.vnc/kasmvnc.log"

  pkill -f "Xkasmvnc ${display} " >/dev/null 2>&1 || true
  sleep 1
  rm -f "/tmp/.X${num}-lock" "/tmp/.X11-unix/X${num}"

  sudo -u "${owner}" bash -c "setsid '${KASM_BIN}' '${display}' \
    -geometry '${VNC_GEOMETRY}' -depth '${VNC_DEPTH}' \
    -SecurityTypes None -sslOnly 0 -disableBasicAuth -ac \
    -interface '${KASM_BIND}' \
    -websocketPort '${web_port}' -rfbport '${rfb_port}' \
    -httpd '${KASM_WEB_DIR}' >'${log}' 2>&1 &"

  for _ in $(seq 1 50); do
    [ -S "/tmp/.X11-unix/X${num}" ] && break
    sleep 0.2
  done

  sudo -u "${owner}" env DISPLAY="${display}" HOME="${home}" \
    setsid bash "${home}/.vnc/xstartup" >>"${log}" 2>&1 &
}

# root 会话(:1) 与 user 会话(:2)，浏览器分别访问 10001 / 10002
ensure_xstartup root /root "${DESKTOP_CMD}"
start_session :1 10001 5901 root /root

ensure_xstartup user /home/user "${DESKTOP_CMD}"
start_session :2 10002 5902 user /home/user

xdg-open http://localhost:10002

clear
echo "  你好, 世界!"
echo "  很高兴认识你~"
echo "  希望能给你带来更棒的体验,如果有任何问题记得提交Issues哦"
echo ""
echo "      如果没有自动打开界面,请检查一下你的浏览器,是否阻止了弹出式窗口"
echo "  嘿嘿"
echo "  项目主页在:Https://cnb.cool/set/playground/desktop"
echo ""
echo "现在点击 <'端口'> 这个标签开始吧~"
echo "默认是打开的10002端口,如果你需要切换到全root模式,请手动点击<'端口'> - <10001>端口后面的小地球开始吧~"
