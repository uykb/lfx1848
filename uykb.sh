#! /bin/bash
echo -e "  
------------------------------------------------------------------------------
作 者         uykb                                           
项 目 地 址   https://github.com/uykb/lfx1848 
博 客         www.lfx1848.cc

-------------------------v2-ui&bbr-plus 一键安装脚本---------------------------
        1. 安装 v2-ui
        2. 安装 BBR PLUS
        3. 安装 BBR PLUS修正版
        4. 安装 宝塔面板
------------------------------------------------------------------------------
"
echo "请输入数字1-4进行选择 并 回车确认"

read chosen

if (($chosen==1));then
        bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
elif (($chosen==2));then
        wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
elif (($chosen==3));then
        wget "https://github.com/cx9208/bbrplus/raw/master/ok_bbrplus_centos.sh" && chmod +x ok_bbrplus_centos.sh && ./ok_bbrplus_centos.sh
elif (($chosen==4));then
        yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
else
        echo "输入命令有误"
 	yum -y update && ./uykb.sh
	fi
}
