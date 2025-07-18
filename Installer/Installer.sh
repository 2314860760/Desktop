#!/bin/bash
#设置默认root密码(修改其中的 123qwe= 为你想要修改的密码也可以哦~)
echo -e 'root:123qwe=' | chpasswd
#设置默认user密码(同上)
echo -e 'user:123qwe=' | chpasswd

echo "密码更新完成">>/tmp/log.txt;

#GPU相关代码
echo 'export PATH=/usr/NX/scripts/vgl:$PATH' >> /etc/profile
env | grep -Ev "CMD=|PWD=|SHLVL=|_=|DEBIAN_FRONTEND=|USER=|HOME=|UID=|GID=|PASSWORD=" > /etc/environment
usermod -aG sudo user
usermod -aG ssl-cert user
chsh -s /bin/bash user
echo "设置GPU代码完成">>/tmp/log.txt;

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
echo "设置vnc密码完成">>/tmp/log.txt;

#重启Dbus
service dbus restart
echo "重启dbus完成">>/tmp/log.txt;

#设置数据库密码
service mariadb start
mysql -u root <<EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('123qwe=');
FLUSH PRIVILEGES;
EOF
echo "设置密码完成">>/tmp/log.txt;

#设置硬件加速快捷方式
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=显卡加速\nComment=拖放程序到这里添加显卡加速\nIcon=video-display\nExec=vglrun %F\nType=Application\nTerminal=false\nCategories=Utility;\nMimeType=application/x-desktop;' > /usr/share/applications/vglrun-adder.desktop
ln -s /usr/share/applications/vglrun-adder.desktop /home/user/桌面/vglrun.desktop
ln -s /usr/share/applications/vglrun-adder.desktop /root/桌面/vglrun.desktop

#创建IDEA全家桶快捷方式
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=CLion\nIcon=/opt/clion-2025.1.1/bin/clion.png\nExec=vglrun /opt/clion-2025.1.1/bin/clion\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/Clion.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Datagrip\nIcon=/opt/DataGrip-2025.1.2/bin/datagrip.png\nExec=vglrun /opt/DataGrip-2025.1.2/bin/datagrip\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/datagrip.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=GoLand\nIcon=/opt/GoLand-2025.1.1/bin/goland.png\nExec=vglrun /opt/GoLand-2025.1.1/bin/goland\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/Goland.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=IntelliJ IDEA\nIcon=/opt/idea-IU-251.25410.129/bin/idea.png\nExec=vglrun /opt/idea-IU-251.25410.129/bin/idea\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/IntelijIdea.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=PhpStorm\nIcon=/opt/PhpStorm-251.25410.148/bin/phpstorm.png\nExec=vglrun /opt/PhpStorm-251.25410.148/bin/phpstorm\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/Phpstorm.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=PyCharm\nIcon=/opt/pycharm-2025.1.1.1/bin/pycharm.png\nExec=vglrun /opt/pycharm-2025.1.1.1/bin/pycharm\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/Pycharm.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Rider\nIcon=/opt/Rider-2025.1.2/bin/rider.png\nExec=vglrun /opt/Rider-2025.1.2/bin/rider\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/rider.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=RubyMine\nIcon=/opt/RubyMine-2025.1.1/bin/rubymine.png\nExec=vglrun /opt/RubyMine-2025.1.1/bin/rubymine\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/Rubymine.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=WebStorm\nIcon=/opt/WebStorm-251.25410.117/bin/webstorm.png\nExec=vglrun /opt/WebStorm-251.25410.117/bin/webstorm\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/Webstorm.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Dataspell\nIcon=/opt/dataspell-2025.1.2/bin/dataspell.png\nExec=vglrun /opt/dataspell-2025.1.2/bin/dataspell\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/Dataspell.desktop
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=RustRover\nIcon=/opt/RustRover-2025.1.5/bin/rustrover.png\nExec=vglrun /opt/RustRover-2025.1.5/bin/rustrover\nTerminal=false\nCategories=Development;IDE\nStartupNotify=true' > /usr/share/applications/RustRover.desktop
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
ln -s /usr/share/applications/Dataspell.desktop /root/桌面/IntelijIDEA/dataspell.desktop
ln -s /usr/share/applications/RustRover.desktop /root/桌面/IntelijIDEA/rustrover.desktop

#创建vscode快捷方式
sed -i 's|Exec=/usr/share/code/code %F|Exec=/usr/share/code/code --no-sandbox %F|' /usr/share/applications/code.desktop
ln -s /usr/share/applications/code.desktop /root/桌面/code.desktop

#创建QQ快捷方式
sed -i 's|Exec=/opt/QQ/qq %U|Exec=vglrun /opt/QQ/qq --no-sandbox %U|' /usr/share/applications/qq.desktop
ln -s /usr/share/applications/qq.desktop /root/桌面/QQ.desktop
#创建微信快捷方式
echo -e '[Desktop Entry]\nVersion=1.0\nType=Application\nName=微信\nIcon=wechat\nExec=vglrun /opt/wechat/wechat\nTerminal=false\nCategories=Network;\nStartupNotify=true' > /usr/share/applications/wechat.desktop
ln -s /usr/share/applications/wechat.desktop /root/桌面/wechat.desktop 
#创建CrossOver快捷方式
echo -e '#!/usr/bin/env xdg-open\n\n[Desktop Entry]\nEncoding=UTF-8\nType=Application\nX-Created-By=cxoffice-0\nCategories=X-cxmenu-cxoffice-0-29ra4ke;\nStartupNotify=true\nStartupWMClass=crossover\nIcon=cxmenu-cxoffice-0-crossover\nExec=vglrun /opt/cxoffice/bin/crossover %u\nName=Win跨平台crossover\nComment=Run Windows software with CrossOver' > /root/桌面/crossover.desktop
#创建FTP快捷方式
ln -s /usr/share/applications/filezilla.desktop /root/桌面/filezilla.desktop
#创建数据库管理器DBeaver快捷方式
ln -s /usr/share/applications/dbeaver-ce.desktop /root/桌面/dbeaver.desktop
#firefox浏览器快捷方式
ln -s /usr/share/applications/firefox.desktop /root/桌面/firefox.desktop
sed -i 's/^Exec=firefox %u/Exec=vglrun firefox %u/' /usr/share/applications/firefox.desktop
#修复Home变量
sed -i 's|export HOME=$(echo -e "/root")||' /etc/profile
mkdir -p /root/Desktop
cp -r /root/桌面/* /root/Desktop
echo "设置桌面快捷方式完成">>/tmp/log.txt;

#创建非root账号快捷方式
mkdir -p /home/user/桌面 && chown -R user:user /home/user/桌面
cp -r /root/桌面/IntelijIDEA /home/user/桌面
ln -s /usr/share/applications/code.desktop /home/user/桌面/code.desktop
ln -s /usr/share/applications/qq.desktop /home/user/桌面/QQ.desktop
ln -s /usr/share/applications/wechat.desktop /home/user/桌面/wechat.desktop
cp /root/桌面/crossover.desktop /home/user/桌面/crossover.desktop
ln -s /usr/share/applications/filezilla.desktop /home/user/桌面/filezilla.desktop
ln -s /usr/share/applications/dbeaver-ce.desktop /home/user/桌面/dbeaver.desktop
ln -s /usr/share/applications/firefox.desktop /home/user/桌面/firefox.desktop

chown -R user:user /home/user/桌面/IntelijIDEA
chown -R user:user /home/user/桌面/*.desktop
chown -R user:user /home/user

#LXQT桌面特定设置
mkdir -p /home/user/Desktop && chown -R user:user /home/user/Desktop
cp -r /home/user/桌面/IntelijIDEA /home/user/Desktop
cp /home/user/桌面/*.desktop /home/user/Desktop/
chown -R user:user /home/user/Desktop/IntelijIDEA
chown -R user:user /home/user/Desktop/*.desktop

#更新软件库
apt update

#安装其他
ln -sf /usr/NX/scripts/vgl/vglrun /usr/bin

echo "完成启动">>/tmp/log.txt;
