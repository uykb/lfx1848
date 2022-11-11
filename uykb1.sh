#! /bin/bash
DATE=`date`
echo -e "  
------------------------------------------------------------------------------                                        
项 目 地 址   https://github.com/uykb/lfx1848 
博 客         www.lfx1848.cc
"当前时间: $DATE"
-------------------------多功能一键安装脚本---------------------------
        1. debian更换Debian sid
        2. 安装 BBR PLUS
        3. 性能调优
        4. 限制IP登录服务器
        5. 安装 docker
        6. 安装X-ui docker版本
        7. 安装UFW防火墙
        8. 安装 Hysteria
        9. 安装 宝塔面板
        10.安装 v2-ui 魔改版
        0. 退出脚本
------------------------------------------------------------------------------
"
echo "请输入数字进行选择 并 回车确认"

read chosen

if   (($chosen==1));then
      apt update -y && apt upgrade -y && echo deb http://deb.debian.org/debian unstable main contrib non-free>/etc/apt/sources.list && apt update -y && apt upgrade -y && apt install linux-image-cloud-amd64 -y && apt autoremove -y && reboot
elif (($chosen==2));then
      wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh && chmod 755 /opt/bbr.sh && /opt/bbr.sh  
elif (($chosen==3));then
      echo -e 'net.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=cake\nnet.ipv4.tcp_slow_start_after_idle=0\nnet.ipv4.tcp_notsent_lowat=16384\nnet.core.rmem_max=4000000' >> /etc/sysctl.conf && sysctl -p  
elif (($chosen==4));then
      echo sshd:154.23.244.188,45.155.223.35,45.61.164.230,52.185.94.74,141.147.157.213,5.75.137.8:allow>/etc/hosts.allow && echo sshd:ALL>/etc/hosts.deny && /bin/systemctl restart sshd.service 
elif (($chosen==5));then
      apt install docker.io  
elif (($chosen==6));then
    mkdir x-ui && cd x-ui
    docker run -itd --network=host \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui:latest
    docker build -t x-ui .  
elif (($chosen==7));then
    apt install ufw
ufw limit ssh
ufw allow https
ufw enable   
elif (($chosen==8));then
     bash <(curl -fsSL https://git.io/hysteria.sh)   
elif (($chosen==9));then
     wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && sudo bash install.sh forum  
elif (($chosen==10));then
     bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install_en.sh)
elif (($chosen==0));then
        exit 0 
else
        echo "输入命令有误"
        wget -N --no-check-certificate "https://raw.githubusercontent.com/uykb/lfx1848/main/uykb1.sh" && chmod +x uykb1.sh && ./uykb1.sh
fi

