#! /bin/bash
DATE=`date`
UNAME=`uname -a`
# 检测系统发行版代号
function getLinuxOSRelease(){
    if [[ -f /etc/redhat-release ]]; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /etc/issue | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /proc/version | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    fi

    getLinuxOSVersion
    checkArchitecture
	checkCPU

    [[ -z $(echo $SHELL|grep zsh) ]] && osSystemShell="bash" || osSystemShell="zsh"

    green " OS info: ${osInfo}, ${osRelease}, ${osReleaseVersion}, ${osReleaseVersionNo}, ${osReleaseVersionCodeName}, ${osCPU} CPU ${osArchitecture}, ${osSystemShell}, ${osSystemPackage}, ${osSystemMdPath}"
}


function promptContinueOpeartion(){
	read -p "是否继续操作? 直接回车默认继续操作, 请输入[Y/n]:" isContinueInput
	isContinueInput=${isContinueInput:-Y}

	if [[ $isContinueInput == [Yy] ]]; then
		echo ""
	else 
		exit 1
	fi
}

echo -e "  
------------------------------------------------------------------------------                                        
项 目 地 址   https://github.com/uykb/lfx1848 
博 客         www.lfx1848.cc
"时间: $DATE"
"系统: $UNAME"
-------------------------多功能一键安装脚本---------------------------
        1. 安装 v2-ui
        2. 安装 BBR PLUS
        3. 安装 LNMP一键安装包
        4. 安装 宝塔面板
        5. 安装 Hysteria
        6. 安装 一键DD系统脚本 
        7. 一件安装docker环境
        8. 同步北京时间➕关闭防火墙➕更新
        0. 退出脚本
------------------------------------------------------------------------------
"
echo "请输入数字1-8进行选择 并 回车确认"

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
elif (($chosen==7));then
        yum install -y yum-utils && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum makecache fast && yum -y install docker-ce && systemctl start docker && systemctl enable docker
elif (($chosen==8));then
        yum -y install ntpdate && timedatectl set-timezone Asia/Shanghai && ntpdate ntp1.aliyun.com && systemctl start supervisord && systemctl disable firewalld && systemctl stop firewalld && yum -y update && yum -y upgrade
elif (($chosen==0));then
        exit 0 
else
        echo "输入命令有误"
        wget -N --no-check-certificate "https://raw.githubusercontent.com/uykb/lfx1848/main/uykb.sh" && chmod +x uykb.sh && ./uykb.sh
fi

