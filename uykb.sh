#! /bin/bash
DATE=`date`
echo -e "  
------------------------------------------------------------------------------                                        
项 目 地 址   https://github.com/uykb/lfx1848 
博 客         www.lfx1848.cc
"当前时间: $DATE"
-------------------------多功能一键安装脚本---------------------------
        1. 安装 v2-ui 魔改版
        2. 安装 BBR PLUS
        3. 安装 NaiveProxy
        4. 安装 宝塔面板
        5. 安装 Hysteria
        6. 安装 一键vmess脚本 
        7. 安装 docker环境
        8. 设置 关闭防火墙
        9. 限制🚫IP登录服务器
        10.安装X-ui docker版本
        11.更换阿里云源
        12.脚本跑分测速
        13.gost转发
        0. 退出脚本
------------------------------------------------------------------------------
"
echo "请输入数字进行选择 并 回车确认"

read chosen

if (($chosen==1));then
        bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install_en.sh)
elif (($chosen==2));then
        wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh && chmod 755 /opt/bbr.sh && /opt/bbr.sh
elif (($chosen==3));then
        wget https://raw.githubusercontent.com/imajeason/nas_tools/main/NaiveProxy/install.sh && bash install.sh
elif (($chosen==4));then
        wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && sudo bash install.sh forum
elif (($chosen==5));then
        bash <(curl -fsSL https://git.io/hysteria.sh)
elif (($chosen==6));then
        wget 'https://cdn.n101.workers.dev/https://raw.githubusercontent.com/daycat/stupid-simple-vmess/main/install.sh' -O install.sh && bash install.sh
elif (($chosen==7));then
        apt-get -y update && apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && mkdir -p /etc/apt/keyrings
 curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && apt-get update -y && apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
elif (($chosen==8));then
        systemctl disable firewalld && systemctl stop firewalld && systemctl mask --now firewalld && ./uykb.sh
elif (($chosen==9));then
        echo sshd:45.61.164.230:allow>/etc/hosts.allow && echo sshd:ALL>/etc/hosts.deny && /bin/systemctl restart sshd.service
elif (($chosen==10));then
        mkdir x-ui && cd x-ui
docker run -itd --network=host \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui:latest
    docker build -t x-ui .
elif (($chosen==11));then
        cd /etc/yum.repos.d/ && cp CentOS-Base.repo CentOS-Base.repo.bak && wget -O CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo && yum clean all && yum update -y && yum makecache -y
elif (($chosen==12));then
        wget -qO- bench.sh | bash
elif (($chosen==13));then
        wget --no-check-certificate -O gost.sh https://raw.githubusercontent.com/KANIKIG/Multi-EasyGost/master/gost.sh && chmod +x gost.sh && ./gost.sh        
elif (($chosen==0));then
        exit 0 
else
        echo "输入命令有误"
        wget -N --no-check-certificate "https://raw.githubusercontent.com/uykb/lfx1848/main/uykb.sh" && chmod +x uykb.sh && ./uykb.sh
fi

