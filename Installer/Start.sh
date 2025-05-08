#/bin/bash

#启动VNC服务
#vncserver && websockify -D --web=/usr/share/novnc/ 10001 localhost:5901
#sudo -u user vncserver && websockify -D --web=/usr/share/novnc/ 10002 localhost:5902

xdg-open http://localhost:10002

clear
echo "  你好, 世界!"
echo "  很高兴认识你~"
echo "  希望能给你带来更棒的体验,如果有任何问题记得提交Issues哦"
echo ""
echo "  嘿嘿"
echo "  项目主页在:Https://cnb.cool/set/playground/desktop"
echo ""
echo "现在点击 <'端口'> 这个标签开始吧~"
echo "默认是打开的10002端口,如果你需要切换到全root模式,请手动点击<'端口'> - <10001>端口后面的小地球开始吧~"

