#!/bin/bash

DATE=`date`

# 检测操作系统类型和包管理器
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    else
        OS="unknown"
    fi

    # 检测包管理器
    if command -v apt-get &> /dev/null; then
        PKG_MGR="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MGR="yum"
    elif command -v apk &> /dev/null; then
        PKG_MGR="apk"
    elif command -v pacman &> /dev/null; then
        PKG_MGR="pacman"
    elif command -v zypper &> /dev/null; then
        PKG_MGR="zypper"
    else
        PKG_MGR="unknown"
    fi

    # 检测init系统
    if command -v systemctl &> /dev/null; then
        INIT_SYS="systemd"
    elif [ -d /etc/init.d ]; then
        INIT_SYS="sysvinit"
    elif command -v rc-service &> /dev/null; then
        INIT_SYS="openrc"
    else
        INIT_SYS="unknown"
    fi
}

detect_os

# 服务管理函数
service_restart() {
    local svc=$1
    case $INIT_SYS in
        systemd)
            systemctl restart $svc 2>/dev/null || systemctl restart ${svc}.service 2>/dev/null
            ;;
        openrc)
            rc-service $svc restart 2>/dev/null
            ;;
        sysvinit)
            /etc/init.d/$svc restart 2>/dev/null || service $svc restart 2>/dev/null
            ;;
    esac
}

# 包安装函数
pkg_install() {
    case $PKG_MGR in
        apt)
            apt update -y && apt install -y "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        yum)
            yum install -y "$@"
            ;;
        apk)
            apk update && apk add "$@"
            ;;
        pacman)
            pacman -Sy --noconfirm "$@"
            ;;
        zypper)
            zypper refresh && zypper install -y "$@"
            ;;
    esac
}

echo -e "  
------------------------------------------------------------------------------                                        
项 目 地 址   https://github.com/uykb/lfx1848 
当前时间：$DATE
检测到系统: $OS ($PKG_MGR 包管理器, $INIT_SYS 初始化系统)
-------------------------多功能一键安装脚本---------------------------
        1. 升级系统内核/源
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
    case $OS in
        debian)
            echo "正在升级到 Debian sid..."
            apt update -y && apt upgrade -y
            echo "deb http://deb.debian.org/debian unstable main contrib non-free" > /etc/apt/sources.list
            apt update -y && apt upgrade -y
            pkg_install linux-image-cloud-amd64
            apt autoremove -y && reboot
            ;;
        ubuntu)
            echo "正在升级 Ubuntu 系统..."
            apt update -y && apt upgrade -y
            do-release-upgrade -y || echo "请手动执行 do-release-upgrade"
            ;;
        alpine)
            echo "正在升级 Alpine 系统..."
            apk update && apk upgrade
            echo "Alpine 升级完成，如需升级大版本请修改 /etc/apk/repositories"
            ;;
        centos|rhel|rocky|almalinux)
            echo "正在升级 RHEL 系系统..."
            if [ "$PKG_MGR" = "dnf" ]; then
                dnf update -y && dnf upgrade -y
            else
                yum update -y && yum upgrade -y
            fi
            ;;
        fedora)
            echo "正在升级 Fedora 系统..."
            dnf upgrade --refresh -y
            ;;
        arch)
            echo "正在升级 Arch Linux..."
            pacman -Syu --noconfirm
            ;;
        *)
            echo "当前系统 $OS 不支持此功能，请手动升级"
            ;;
    esac
elif ((chosen==2)); then
    echo "正在安装 BBR PLUS..."
    case $PKG_MGR in
        apt)
            pkg_install wget ca-certificates
            ;;
        dnf|yum)
            pkg_install wget ca-certificates
            ;;
        apk)
            pkg_install wget ca-certificates
            ;;
        pacman)
            pkg_install wget ca-certificates
            ;;
    esac
    wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
    chmod 755 /opt/bbr.sh
    /opt/bbr.sh
elif ((chosen==3)); then
    echo "正在进行性能调优..."
    case $OS in
        alpine)
            echo -e 'net.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=cake\nnet.ipv4.tcp_slow_start_after_idle=0\nnet.ipv4.tcp_notsent_lowat=16384\nnet.core.rmem_max=4000000' >> /etc/sysctl.conf
            sysctl -p
            ;;
        *)
            echo -e 'net.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=cake\nnet.ipv4.tcp_slow_start_after_idle=0\nnet.ipv4.tcp_notsent_lowat=16384\nnet.core.rmem_max=4000000' >> /etc/sysctl.conf
            sysctl -p
            ;;
    esac
    echo "性能调优完成"
elif ((chosen==4)); then
    echo "请输入允许登录的IP地址（多个IP用空格分隔）："
    read -a allow_ips
    if [ ${#allow_ips[@]} -eq 0 ]; then
        echo "IP地址不能为空"
        exit 1
    fi
    # 确保 /etc 目录存在 (Alpine 默认存在)
    mkdir -p /etc
    # 写入 hosts.allow
    > /etc/hosts.allow
    for ip in "${allow_ips[@]}"; do
        echo "sshd:$ip:allow" >> /etc/hosts.allow
    done
    # 写入 hosts.deny
    echo "sshd:ALL" > /etc/hosts.deny
    # 重启 SSH 服务
    case $OS in
        alpine)
            service_restart sshd
            ;;
        debian|ubuntu)
            service_restart ssh
            ;;
        *)
            service_restart sshd
            ;;
    esac
    echo "已配置仅允许IP ${allow_ips[*]} 登录SSH"
elif ((chosen==5)); then
    echo "正在安装 Docker..."
    case $OS in
        alpine)
            pkg_install docker docker-cli-compose
            service_restart docker
            rc-update add docker default 2>/dev/null || true
            ;;
        debian|ubuntu)
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            rm -f get-docker.sh
            ;;
        centos|rhel|rocky|almalinux|fedora)
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            rm -f get-docker.sh
            ;;
        arch)
            pkg_install docker
            service_restart docker
            systemctl enable docker 2>/dev/null || true
            ;;
        *)
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            rm -f get-docker.sh
            ;;
    esac
    usermod -aG docker $(whoami) 2>/dev/null || true
    echo "Docker 安装完成，请重新登录以应用 docker 用户组权限"
elif ((chosen==6)); then
    echo "开始快速清理 Linux 资源..."
    # 检查 root 权限
    if [ $EUID -ne 0 ]; then
        echo "此功能需要 root 权限运行"
        exit 1
    fi
    # 清理包管理器缓存
    case $PKG_MGR in
        apt)
            echo "[Debian/Ubuntu] 清理 apt 缓存和孤立包..."
            apt-get autoremove -y 2>/dev/null || true
            apt-get clean 2>/dev/null || true
            ;;
        dnf)
            echo "[RHEL/Fedora] 清理 dnf 缓存..."
            dnf clean all 2>/dev/null || true
            dnf autoremove -y 2>/dev/null || true
            ;;
        yum)
            echo "[CentOS] 清理 yum 缓存..."
            yum clean all 2>/dev/null || true
            yum autoremove -y 2>/dev/null || true
            ;;
        apk)
            echo "[Alpine] 清理 apk 缓存..."
            rm -rf /var/cache/apk/* 2>/dev/null || true
            ;;
        pacman)
            echo "[Arch] 清理 pacman 缓存..."
            if command -v paccache &> /dev/null; then
                paccache -rk1 2>/dev/null || true
            else
                pacman -Sc --noconfirm 2>/dev/null || true
            fi
            pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null || true
            ;;
        zypper)
            echo "[openSUSE] 清理 zypper 缓存..."
            zypper clean --all 2>/dev/null || true
            ;;
    esac
    # 清理系统日志
    if command -v journalctl &> /dev/null; then
        echo "清理 systemd 日志 (保留100M)..."
        journalctl --vacuum-size=100M 2>/dev/null || true
    fi
    # Alpine 日志清理
    if [ -d /var/log ]; then
        find /var/log -type f -name "*.log" -size +50M -exec truncate -s 0 {} \; 2>/dev/null || true
    fi
    # 清理临时文件
    echo "清理 /tmp 和 /var/tmp 中超过7天的文件..."
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    # 清理缩略图缓存
    rm -rf /root/.cache/thumbnails/* 2>/dev/null || true
    # 清理崩溃报告
    rm -rf /var/crash/* 2>/dev/null || true
    # 清理 Docker 资源
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo "清理 Docker 悬空镜像和停止的容器..."
        docker system prune -f 2>/dev/null || true
    fi
    echo "清理完成！"
    df -h / 2>/dev/null || true
elif ((chosen==0)); then
    exit 0 
else
    echo "输入命令有误"
    wget -N --no-check-certificate "https://raw.githubusercontent.com/uykb/lfx1848/main/uykb1.sh" && chmod +x uykb1.sh && ./uykb1.sh
fi
