#!/bin/bash

DATE=`date`

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    else
        OS="unknown"
    fi
}

detect_os

echo -e "  
------------------------------------------------------------------------------                                        
项 目 地 址   https://github.com/uykb/lfx1848 
当前时间：$DATE
检测到系统: $OS
-------------------------多功能一键安装脚本---------------------------
        1. debian更换Debian sid
        2. 安装 BBR PLUS
        3. 性能调优
        4. 限制IP登录服务器
        5. 安装 Docker
        6. 快速清理 Linux 资源
        0. 退出脚本
------------------------------------------------------------------------------
"

echo "请输入数字进行选择 并 回车确认"

read chosen

if ((chosen==1)); then
    if [ "$OS" = "debian" ]; then
        apt update -y && apt upgrade -y && echo deb http://deb.debian.org/debian unstable main contrib non-free>/etc/apt/sources.list && apt update -y && apt upgrade -y && apt install linux-image-cloud-amd64 -y && apt autoremove -y && reboot
    else
        echo "此选项仅支持 Debian 系统"
    fi
elif ((chosen==2)); then
    wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh && chmod 755 /opt/bbr.sh && /opt/bbr.sh  
elif ((chosen==3)); then
    echo -e 'net.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=cake\nnet.ipv4.tcp_slow_start_after_idle=0\nnet.ipv4.tcp_notsent_lowat=16384\nnet.core.rmem_max=4000000' >> /etc/sysctl.conf && sysctl -p  
elif ((chosen==4)); then
    echo "请输入允许登录的IP地址："
    read allow_ip
    if [ -z "$allow_ip" ]; then
        echo "IP地址不能为空"
        exit 1
    fi
    echo "sshd:$allow_ip:allow" > /etc/hosts.allow
    echo "sshd:ALL" > /etc/hosts.deny
    if command -v systemctl &> /dev/null; then
        systemctl restart sshd
    elif command -v service &> /dev/null; then
        service sshd restart
    else
        /etc/init.d/sshd restart
    fi
    echo "已配置仅允许IP $allow_ip 登录SSH"
elif ((chosen==5)); then
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        usermod -aG docker $(whoami)
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        usermod -aG docker $(whoami)
    else
        echo "不支持的操作系统，请手动安装Docker"
    fi
elif ((chosen==6)); then
    echo "开始快速清理 Linux 资源..."
    # 检查 root 权限
    if [ $EUID -ne 0 ]; then
        echo "此功能需要 root 权限运行"
        exit 1
    fi
    # 清理包管理器缓存
    if command -v apt-get &> /dev/null; then
        echo "[Debian/Ubuntu] 清理 apt 缓存和孤立包..."
        apt-get autoremove -y 2>/dev/null || true
        apt-get clean 2>/dev/null || true
    elif command -v dnf &> /dev/null; then
        echo "[RHEL/Fedora] 清理 dnf 缓存..."
        dnf clean all 2>/dev/null || true
        dnf autoremove -y 2>/dev/null || true
    elif command -v yum &> /dev/null; then
        echo "[CentOS] 清理 yum 缓存..."
        yum clean all 2>/dev/null || true
        yum autoremove -y 2>/dev/null || true
    elif command -v apk &> /dev/null; then
        echo "[Alpine] 清理 apk 缓存..."
        apk cache clean 2>/dev/null || true
    elif command -v pacman &> /dev/null; then
        echo "[Arch] 清理 pacman 缓存..."
        pacman -Sc --noconfirm 2>/dev/null || true
    fi
    # 清理系统日志
    if command -v journalctl &> /dev/null; then
        echo "清理 systemd 日志 (保留100M)..."
        journalctl --vacuum-size=100M 2>/dev/null || true
    fi
    # 清理临时文件
    echo "清理 /tmp 和 /var/tmp 中超过7天的文件..."
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    # 清理 Docker 资源
    if command -v docker &> /dev/null; then
        echo "清理 Docker 悬空镜像和停止的容器..."
        docker system prune -f 2>/dev/null || true
    fi
    echo "清理完成！"
elif ((chosen==0)); then
    exit 0 
else
    echo "输入命令有误"
    wget -N --no-check-certificate "https://raw.githubusercontent.com/uykb/lfx1848/main/uykb1.sh" && chmod +x uykb1.sh && ./uykb1.sh
fi
