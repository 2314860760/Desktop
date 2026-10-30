#/bin/bash

#设置默认root密码(修改其中的 123qwe= 为你想要修改的密码也可以哦~)
echo -e 'root:123qwe=' | chpasswd
#设置默认user密码(同上)
echo -e 'user:123qwe=' | chpasswd


#设置root远程密码（可以修改这里的密码）
rm -rf /root/.vnc/passwd
mkdir -p /root/.vnc && vncpasswd <<EOF
123qwe=
123qwe=
n
EOF
#设置user远程密码(同上)
rm -rf /home/user/.vnc/passwd
mkdir -p /home/user/.vnc && chown -R user:user /home/user/.vnc && sudo -u user vncpasswd <<EOF
123qwe=
123qwe=
n
EOF

#重启Dbus
service dbus restart

#设置数据库密码
service mariadb start
mysql -u root <<EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('123qwe=');
FLUSH PRIVILEGES;
EOF

#创建IDEA全家桶快捷方式
#按通配符匹配已安装目录（多个版本时取版本号最大者），IDE升级后无需改脚本
ide_root() {
  local pattern="$1" d
  for d in $pattern; do
    [ -d "$d/bin" ] && printf '%s\n' "$d"
  done | sort -V | tail -n 1
}

#参数: desktop文件名 显示名称 安装目录通配符 启动程序名
make_ide_desktop() {
  local file="$1" name="$2" pattern="$3" bin="$4" root
  root="$(ide_root "$pattern")"
  if [ -z "$root" ]; then
    echo "[跳过] 未安装 $name"
    rm -f "/usr/share/applications/$file"
    return 0
  fi
  #显式带上输入法环境变量，避免IDE从无XMODIFIERS的入口启动后整个窗口无法调用输入法
  echo -e "[Desktop Entry]\nVersion=1.0\nType=Application\nName=$name\nIcon=$root/bin/$bin.png\nExec=env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx $root/bin/$bin\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true" > "/usr/share/applications/$file"
  echo "[快捷方式] $name -> $root"
}

make_ide_desktop Clion.desktop "CLion" "/opt/clion-*" clion
make_ide_desktop datagrip.desktop "Datagrip" "/opt/DataGrip-*" datagrip
make_ide_desktop Goland.desktop "GoLand" "/opt/GoLand-*" goland
make_ide_desktop IntelijIdea.desktop "IntelliJ IDEA" "/opt/idea-IU-*" idea
make_ide_desktop Phpstorm.desktop "PhpStorm" "/opt/PhpStorm-*" phpstorm
make_ide_desktop Pycharm.desktop "PyCharm" "/opt/pycharm-*" pycharm
make_ide_desktop rider.desktop "Rider" "/opt/Rider-*" rider
make_ide_desktop Rubymine.desktop "RubyMine" "/opt/RubyMine-*" rubymine
make_ide_desktop Webstorm.desktop "WebStorm" "/opt/WebStorm-*" webstorm
make_ide_desktop Dataspell.desktop "Dataspell" "/opt/dataspell-*" dataspell
make_ide_desktop RustRover.desktop "RustRover" "/opt/RustRover-*" rustrover

#修复JetBrains系IDE的中文输入(JBR 21+ 在X11下有时拿不到XIM，表现为输入法在IDE内根本切不出来)
#awt.toolkit.name=auto 在X11会话里可能选到Wayland工具箱(不支持XIM)，这里强制回XToolkit
for vm in /opt/*/bin/*64.vmoptions; do
  [ -f "$vm" ] || continue
  grep -qxF -- '-Drecreate.x11.input.method=true' "$vm" || echo '-Drecreate.x11.input.method=true' >> "$vm"
  sed -i 's|^-Dawt.toolkit.name=.*|-Dawt.toolkit.name=XToolkit|' "$vm"
done
#创建Root用户快捷方式
mkdir -p /root/桌面/IntelijIDEA/
ln -s /usr/share/applications/Rubymine.desktop /root/桌面/IntelijIDEA/rubymine.desktop
ln -s /usr/share/applications/Phpstorm.desktop /root/桌面/IntelijIDEA/phpstorm.desktop
ln -s /usr/share/applications/Webstorm.desktop /root/桌面/IntelijIDEA/webstorm.desktop
ln -s /usr/share/applications/Clion.desktop /root/桌面/IntelijIDEA/clion.desktop
ln -s /usr/share/applications/Pycharm.desktop /root/桌面/IntelijIDEA/pycharm.desktop
ln -s /usr/share/applications/Goland.desktop /root/桌面/IntelijIDEA/goland.desktop
ln -s /usr/share/applications/IntelijIdea.desktop /root/桌面/IntelijIDEA/idea.desktop
ln -s /usr/share/applications/datagrip.desktop /root/桌面/IntelijIDEA/datagrip.desktop
ln -s /usr/share/applications/rider.desktop /root/桌面/IntelijIDEA/rider.desktop
[ -e /usr/share/applications/Dataspell.desktop ] && ln -s /usr/share/applications/Dataspell.desktop /root/桌面/IntelijIDEA/dataspell.desktop
ln -s /usr/share/applications/RustRover.desktop /root/桌面/IntelijIDEA/rustrover.desktop

#创建vscode快捷方式
sed -i 's|Exec=/usr/share/code/code %F|Exec=/usr/share/code/code --no-sandbox %F|' /usr/share/applications/code.desktop
#右键“新建窗口”动作同样需要 --no-sandbox，已加过则跳过(脚本每次启动都会执行)
grep -q '^Exec=/usr/share/code/code --new-window' /usr/share/applications/code.desktop 2>/dev/null && sed -i 's|^Exec=/usr/share/code/code --new-window |Exec=/usr/share/code/code --no-sandbox --new-window |' /usr/share/applications/code.desktop || true
ln -s /usr/share/applications/code.desktop /root/桌面/code.desktop

#创建CodeBuddy IDE快捷方式(同样是Electron应用，root下需要--no-sandbox)
sed -i 's|Exec=/usr/share/buddycn/bin/buddycn %F|Exec=/usr/share/buddycn/bin/buddycn --no-sandbox %F|' /usr/share/applications/buddycn.desktop
grep -q '^Exec=/usr/share/buddycn/bin/buddycn --new-window' /usr/share/applications/buddycn.desktop 2>/dev/null && sed -i 's|^Exec=/usr/share/buddycn/bin/buddycn --new-window |Exec=/usr/share/buddycn/bin/buddycn --no-sandbox --new-window |' /usr/share/applications/buddycn.desktop || true
ln -s /usr/share/applications/buddycn.desktop /root/桌面/codebuddy-ide.desktop

#创建WorkBuddy快捷方式(同样是Electron应用，root下需要--no-sandbox)
sed -i 's|Exec=/opt/WorkBuddy/workbuddy %U|Exec=/opt/WorkBuddy/workbuddy --no-sandbox %U|' /usr/share/applications/workbuddy.desktop
ln -s /usr/share/applications/workbuddy.desktop /root/桌面/workbuddy.desktop

#创建QQ快捷方式
sed -i 's|Exec=/opt/QQ/qq %U|Exec=/opt/QQ/qq --no-sandbox %U|' /usr/share/applications/qq.desktop
ln -s /usr/share/applications/qq.desktop /root/桌面/QQ.desktop
#创建微信快捷方式
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=微信\nIcon=wechat\nExec=/opt/wechat/wechat\nTerminal=false\nCategories=Network;\nStartupNotify=true' > /usr/share/applications/wechat.desktop
ln -s /usr/share/applications/wechat.desktop /root/桌面/wechat.desktop 
#创建CrossOver快捷方式
echo -e '#!/usr/bin/env xdg-open\n\n[Desktop Entry]\nEncoding=UTF-8\nType=Application\nX-Created-By=cxoffice-0\nCategories=X-cxmenu-cxoffice-0-29ra4ke;\nStartupNotify=true\nStartupWMClass=crossover\nIcon=cxmenu-cxoffice-0-crossover\nExec=/opt/cxoffice/bin/crossover %u\nName=Win跨平台crossover\nComment=Run Windows software with CrossOver' > /root/桌面/crossover.desktop
#创建FTP快捷方式
ln -s /usr/share/applications/filezilla.desktop /root/桌面/filezilla.desktop
#创建数据库管理器DBeaver快捷方式
ln -s /usr/share/applications/dbeaver-ce.desktop /root/桌面/dbeaver.desktop
#修复Home变量
sed -i 's|export HOME=$(echo -e "/root")||' /etc/profile

#创建非root账号快捷方式
mkdir -p /home/user/桌面 && chown -R user:user /home/user/桌面
cp -r /root/桌面/IntelijIDEA /home/user/桌面
ln -s /usr/share/applications/code.desktop /home/user/桌面/code.desktop
ln -s /usr/share/applications/buddycn.desktop /home/user/桌面/codebuddy-ide.desktop
ln -s /usr/share/applications/workbuddy.desktop /home/user/桌面/workbuddy.desktop
ln -s /usr/share/applications/qq.desktop /home/user/桌面/QQ.desktop
ln -s /usr/share/applications/wechat.desktop /home/user/桌面/wechat.desktop
cp /root/桌面/crossover.desktop /home/user/桌面/crossover.desktop
ln -s /usr/share/applications/filezilla.desktop /home/user/桌面/filezilla.desktop
ln -s /usr/share/applications/dbeaver-ce.desktop /home/user/桌面/dbeaver.desktop

chown -R user:user /home/user/桌面/IntelijIDEA
chown -R user:user /home/user/桌面/*.desktop
chown -R user:user /home/user

#LXQT桌面特定设置
mkdir -p /home/user/Desktop && chown -R user:user /home/user/Desktop
cp -r /home/user/桌面/IntelijIDEA /home/user/Desktop
cp /home/user/桌面/*.desktop /home/user/Desktop/
chown -R user:user /home/user/Desktop/IntelijIDEA
chown -R user:user /home/user/Desktop/*.desktop

#创建Agent服务文件夹(自动适配不同桌面的桌面目录)
#优先读 XDG 配置(user-dirs.dirs)，再回退到中文/英文桌面目录
agent_desktop_dirs() {
  local home="$1" cfg="$1/.config/user-dirs.dirs" d
  if [ -f "$cfg" ]; then
    d="$(sed -n 's|^XDG_DESKTOP_DIR="\(.*\)"$|\1|p' "$cfg" | tail -n 1)"
    d="${d/\$HOME/$home}"
    [ -n "$d" ] && printf '%s\n' "$d"
  fi
  for d in "$home/桌面" "$home/Desktop"; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

#Agent 命令清单: 显示名|命令|图标
AGENT_CLIS=(
  "ClaudeCode|claude|utilities-terminal"
  "CodeBuddy|codebuddy|buddycn"
  "DeepSeek|dsh|utilities-terminal"
  "Codex|codex|utilities-terminal"
  "Gemini|gemini|utilities-terminal"
  "Copilot|copilot|utilities-terminal"
  "Qwen|qwen|utilities-terminal"
  "Amp|amp|utilities-terminal"
  "Crush|crush|utilities-terminal"
  "OpenCode|opencode|utilities-terminal"
  "Continue|cn|utilities-terminal"
  "iFlow|iflow|utilities-terminal"
  "Cursor|cursor-agent|utilities-terminal"
)

make_agent_shortcuts() {
  local home="$1" owner="$2" dir dirs entry name cmd icon
  dirs="$(agent_desktop_dirs "$home" | sort -u)"
  [ -n "$dirs" ] || dirs="$home/桌面"
  for dir in $dirs; do
    mkdir -p "$dir/Agent服务"
    for entry in "${AGENT_CLIS[@]}"; do
      IFS='|' read -r name cmd icon <<<"$entry"
      #命令不存在就跳过，避免留下点不开的快捷方式
      command -v "$cmd" >/dev/null 2>&1 || continue
      printf '%s\n' '[Desktop Entry]' 'Version=1.0' 'Type=Application' "Name=$name" "Comment=$name 终端" "Icon=$icon" "Exec=$cmd" 'Terminal=true' 'Categories=Development;' > "$dir/Agent服务/$name.desktop"
    done
    #CodeBuddy IDE 直接复用安装包自带的 desktop 文件(前面已加 --no-sandbox)
    #只改主入口的 Name，不能动 [Desktop Action] 里的 Name
    sed '0,/^Name=/{s|^Name=.*|Name=CodeBuddy IDE|}' /usr/share/applications/buddycn.desktop > "$dir/Agent服务/CodeBuddy IDE.desktop"
    #WorkBuddy 桌面端同样放进来(desktop 文件前面已加 --no-sandbox)
    [ -f /usr/share/applications/workbuddy.desktop ] && cp -f /usr/share/applications/workbuddy.desktop "$dir/Agent服务/WorkBuddy.desktop" || true
    chmod +x "$dir/Agent服务/"*.desktop
    chown -R "$owner:$owner" "$dir/Agent服务"
  done
}

make_agent_shortcuts /root root
make_agent_shortcuts /home/user user

#安装其他



