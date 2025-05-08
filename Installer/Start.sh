#/bin/bash

#启动VNC服务
vncserver && websockify -D --web=/usr/share/novnc/ 10001 localhost:5901
sudo -u user vncserver && websockify -D --web=/usr/share/novnc/ 10002 localhost:5902
