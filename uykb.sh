#! /bin/bash
echo -e "  
------------------------------------------------------------------------------
作 者         uykb                                           
项 目 地 址   https://github.com/uykb/lfx1848 
博 客         www.lfx1848.cc

-------------------------多功能一键安装脚本---------------------------
        1. 安装 v2-ui
        2. 安装 BBR PLUS
        3. 安装 LNMP一键安装包
        4. 安装 宝塔面板
        5. 安装 Hysteria
        6. 安装 一键DD系统脚本       
------------------------------------------------------------------------------
"
echo "请输入数字1-6进行选择 并 回车确认"

read chosen

if (($chosen==1));then
        bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
elif (($chosen==2));then
        wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
elif (($chosen==3));then
        wget http://soft.vpser.net/lnmp/lnmp1.8.tar.gz -cO lnmp1.8.tar.gz && tar zxf lnmp1.8.tar.gz && cd lnmp1.8 && ./install.sh lnmp
elif (($chosen==4));then
        yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
elif (($chosen==5));then
        wget -N https://raw.githubusercontent.com/uykb/Hysteria-script/master/hysteria.sh && bash hysteria.sh
elif (($chosen==6));then
        wget https://gitee.com/minlearn/onekeydevdesk/raw/master/inst.sh && chmod +x inst.sh && bash inst.sh
else
        echo "输入命令有误"
        wget -N --no-check-certificate "https://raw.githubusercontent.com/uykb/lfx1848/main/uykb.sh" && chmod +x uykb.sh && ./uykb.sh
fi

