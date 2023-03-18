#!/bin/bash

DATE=`date`

echo -e "  
------------------------------------------------------------------------------                                        
项 目 地 址   https://github.com/uykb/lfx1848 
当前时间：$DATE
-------------------------多功能一键安装脚本---------------------------
        1. debian更换Debian sid
        2. 安装 BBR PLUS
        3. 性能调优
        4. 限制IP登录服务器
        5. 安装 Docker
        0. 退出脚本
------------------------------------------------------------------------------
"

echo "请输入数字进行选择 并 回车确认"

read chosen

if ((chosen==1)); then
    apt update -y && apt upgrade -y && echo deb http://deb.debian.org/debian unstable main contrib non-free>/etc/apt/sources.list && apt update -y && apt upgrade -y && apt install linux-image-cloud-amd64 -y && apt autoremove -y && reboot
elif ((chosen==2)); then
    wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh && chmod 755 /opt/bbr.sh && /opt/bbr.sh  
elif ((chosen==3)); then
    echo -e 'net.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=cake\nnet.ipv4.tcp_slow_start_after_idle=0\nnet.ipv4.tcp_notsent_lowat=16384\nnet.core.rmem_max=4000000' >> /etc/sysctl.conf && sysctl -p  
elif ((chosen==4)); then
    echo sshd:20.113.44.185:allow>/etc/hosts.allow && echo sshd:ALL>/etc/hosts.deny && /bin/systemctl restart sshd.service 
elif ((chosen==5)); then
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    echo 'deb [arch=amd64] https://download.docker.com/linux/debian buster stable' > /etc/apt/sources.list.d/docker.list
    apt update
    apt install docker-ce docker-ce-cli containerd.io
elif ((chosen==0)); then
    exit 0 
else
    echo "输入命令有误"
    wget -N --no-check-certificate "https://raw.githubusercontent.com/uykb/lfx1848/main/uykb1.sh" && chmod +x uykb1.sh && ./uykb1.sh
fi
