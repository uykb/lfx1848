#!/bin/bash

# 检查并自动提权
if [ $EUID -ne 0 ]; then
    echo "检测到非 root 用户，正在尝试使用 sudo 提权..."
    if command -v sudo &> /dev/null; then
        exec sudo "$0" "$@"
    else
        echo "错误：此脚本需要 root 权限运行。请使用 'sudo ./uykb1.sh' 运行。"
        exit 1
    fi
fi

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

# BBR 安装相关函数
bbr_red() {
    printf '\033[1;31;31m%b\033[0m' "$1"
}

bbr_green() {
    printf '\033[1;31;32m%b\033[0m' "$1"
}

bbr_yellow() {
    printf '\033[1;31;33m%b\033[0m' "$1"
}

bbr_info() {
    bbr_green "[Info] "
    printf -- "%s" "$1"
    printf "\n"
}

bbr_error() {
    bbr_red "[Error] "
    printf -- "%s" "$1"
    printf "\n"
    exit 1
}

bbr_exists() {
    local cmd="$1"
    if eval type type > /dev/null 2>&1; then
        eval type "$cmd" > /dev/null 2>&1
    elif command > /dev/null 2>&1; then
        command -v "$cmd" > /dev/null 2>&1
    else
        which "$cmd" > /dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

bbr_is_64bit() {
    if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ]; then
        return 0
    else
        return 1
    fi
}

bbr_version_ge() {
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

bbr_check_bbr_status() {
    local param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ x"${param}" == x"bbr" ]]; then
        return 0
    else
        return 1
    fi
}

bbr_check_kernel_version() {
    local kernel_version=$(uname -r | cut -d- -f1)
    if bbr_version_ge ${kernel_version} 4.9; then
        return 0
    else
        return 1
    fi
}

bbr_sysctl_config() {
    [ -f /etc/sysctl.conf ] && sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    [ -f /etc/sysctl.conf ] && sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

bbr_get_latest_version() {
    local latest_version=($(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/ | awk -F'\"v' '/v[4-9]./{print $2}' | cut -d/ -f1 | grep -v - | sort -V))
    [ ${#latest_version[@]} -eq 0 ] && bbr_error "获取最新内核版本失败"
    local kernel_arr=()
    for i in ${latest_version[@]}; do
        if bbr_version_ge $i 5.15; then
            kernel_arr+=($i);
        fi
    done
    if [ ${#kernel_arr[@]} -gt 0 ]; then
        kernel=${kernel_arr[${#kernel_arr[@]}-1]}
    else
        kernel=${latest_version[${#latest_version[@]}-1]}
    fi
    if bbr_is_64bit; then
        local deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${deb_name}"
        deb_kernel_name="linux-image-${kernel}-amd64.deb"
        local modules_deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "linux-modules" | grep "generic" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_modules_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${modules_deb_name}"
        deb_kernel_modules_name="linux-modules-${kernel}-amd64.deb"
    else
        local deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${deb_name}"
        deb_kernel_name="linux-image-${kernel}-i386.deb"
        local modules_deb_name=$(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/ | grep "linux-modules" | grep "generic" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_modules_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${modules_deb_name}"
        deb_kernel_modules_name="linux-modules-${kernel}-i386.deb"
    fi
    [ -z "${deb_name}" ] && bbr_error "获取内核包名失败"
}

bbr_install_kernel_debian() {
    bbr_info "获取最新内核版本..."
    bbr_get_latest_version
    if [ -n "${modules_deb_name}" ]; then
        wget -c -t3 -T60 -O ${deb_kernel_modules_name} ${deb_kernel_modules_url} || bbr_error "下载内核模块包失败"
    fi
    wget -c -t3 -T60 -O ${deb_kernel_name} ${deb_kernel_url} || bbr_error "下载内核包失败"
    dpkg -i ${deb_kernel_modules_name} ${deb_kernel_name} || bbr_error "安装内核失败"
    rm -f ${deb_kernel_modules_name} ${deb_kernel_name}
    /usr/sbin/update-grub
}

bbr_install_kernel_centos6() {
    bbr_exists perl || pkg_install perl
    local rpm_kernel_url="https://dl.lamp.sh/files/"
    if bbr_is_64bit; then
        local rpm_kernel_name="kernel-ml-4.18.20-1.el6.elrepo.x86_64.rpm"
        local rpm_kernel_devel_name="kernel-ml-devel-4.18.20-1.el6.elrepo.x86_64.rpm"
    else
        local rpm_kernel_name="kernel-ml-4.18.20-1.el6.elrepo.i686.rpm"
        local rpm_kernel_devel_name="kernel-ml-devel-4.18.20-1.el6.elrepo.i686.rpm"
    fi
    wget -c -t3 -T60 -O ${rpm_kernel_name} ${rpm_kernel_url}${rpm_kernel_name} || bbr_error "下载内核失败"
    wget -c -t3 -T60 -O ${rpm_kernel_devel_name} ${rpm_kernel_url}${rpm_kernel_devel_name} || bbr_error "下载内核devel失败"
    rpm -ivh ${rpm_kernel_name} || bbr_error "安装内核失败"
    rpm -ivh ${rpm_kernel_devel_name} || bbr_error "安装内核devel失败"
    rm -f ${rpm_kernel_name} ${rpm_kernel_devel_name}
    [ ! -f "/boot/grub/grub.conf" ] && bbr_error "/boot/grub/grub.conf 不存在"
    sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
}

bbr_install_kernel_centos7() {
    local rpm_kernel_url="https://dl.lamp.sh/kernel/el7/"
    if bbr_is_64bit; then
        local rpm_kernel_name="kernel-ml-5.15.60-1.el7.x86_64.rpm"
        local rpm_kernel_devel_name="kernel-ml-devel-5.15.60-1.el7.x86_64.rpm"
    else
        bbr_error "不支持32位系统"
    fi
    wget -c -t3 -T60 -O ${rpm_kernel_name} ${rpm_kernel_url}${rpm_kernel_name} || bbr_error "下载内核失败"
    wget -c -t3 -T60 -O ${rpm_kernel_devel_name} ${rpm_kernel_url}${rpm_kernel_devel_name} || bbr_error "下载内核devel失败"
    rpm -ivh ${rpm_kernel_name} || bbr_error "安装内核失败"
    rpm -ivh ${rpm_kernel_devel_name} || bbr_error "安装内核devel失败"
    rm -f ${rpm_kernel_name} ${rpm_kernel_devel_name}
    /usr/sbin/grub2-set-default 0
}

bbr_install_kernel() {
    case $OS in
        centos)
            if [ -f /etc/redhat-release ]; then
                local centos_ver=$(awk '{print $3}' /etc/redhat-release | cut -d. -f1)
                if [ "$centos_ver" -eq 6 ]; then
                    bbr_install_kernel_centos6
                elif [ "$centos_ver" -eq 7 ]; then
                    bbr_install_kernel_centos7
                fi
            fi
            ;;
        rhel|rocky|almalinux|fedora)
            bbr_info "使用官方源安装最新内核..."
            if [ "$PKG_MGR" = "dnf" ]; then
                dnf install -y kernel kernel-modules || bbr_error "安装内核失败"
            else
                yum install -y kernel kernel-modules || bbr_error "安装内核失败"
            fi
            grub2-set-default 0 2>/dev/null || true
            ;;
        ubuntu|debian)
            bbr_install_kernel_debian
            ;;
        alpine)
            bbr_info "Alpine 系统安装最新内核..."
            pkg_install linux-lts linux-lts-dev
            update-grub 2>/dev/null || update-extlinux 2>/dev/null || true
            ;;
        arch)
            bbr_info "Arch Linux 系统安装最新内核..."
            pkg_install linux linux-headers
            grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
            ;;
        *)
            bbr_error "不支持的操作系统: $OS"
            ;;
    esac
}

bbr_install() {
    if bbr_check_bbr_status; then
        bbr_info "TCP BBR 已经启用，无需安装"
        return 0
    fi
    if bbr_check_kernel_version; then
        bbr_info "内核版本 >= 4.9，直接启用 BBR..."
        bbr_sysctl_config
        bbr_info "BBR 启用成功"
        return 0
    fi
    bbr_info "内核版本 < 4.9，正在安装新内核..."
    bbr_install_kernel
    bbr_sysctl_config
    bbr_info "安装完成，需要重启系统以应用新内核"
    read -p "是否现在重启系统? [y/n]: " is_reboot
    if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
        reboot
    else
        bbr_info "已取消重启，请手动重启以应用 BBR"
    fi
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
    echo "正在安装 BBR..."
    if [ $EUID -ne 0 ]; then
        echo "此功能需要 root 权限运行"
        exit 1
    fi
    # 安装必要依赖
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
    bbr_install
elif ((chosen==3)); then
    echo "正在进行全面性能调优..."
    if [ $EUID -ne 0 ]; then
        echo "此功能需要 root 权限运行"
        exit 1
    fi
    # 确保 sysctl.conf 存在
    touch /etc/sysctl.conf
    # 定义优化参数数组
    declare -A sysctl_params
    # 网络拥塞控制
    sysctl_params["net.ipv4.tcp_congestion_control"]="bbr"
    sysctl_params["net.core.default_qdisc"]="fq"
    # 连接复用优化
    sysctl_params["net.ipv4.tcp_tw_reuse"]="1"
    sysctl_params["net.ipv4.tcp_fin_timeout"]="30"
    sysctl_params["net.ipv4.tcp_max_syn_backlog"]="16384"
    sysctl_params["net.ipv4.tcp_syncookies"]="1"
    # TCP 性能优化
    sysctl_params["net.ipv4.tcp_slow_start_after_idle"]="0"
    sysctl_params["net.ipv4.tcp_notsent_lowat"]="16384"
    sysctl_params["net.core.rmem_max"]="4000000"
    sysctl_params["net.core.wmem_max"]="4000000"
    sysctl_params["net.ipv4.tcp_rmem"]="4096 87380 4000000"
    sysctl_params["net.ipv4.tcp_wmem"]="4096 65536 4000000"
    sysctl_params["net.core.netdev_max_backlog"]="262144"
    sysctl_params["net.core.somaxconn"]="65535"
    # Keepalive 心跳参数
    sysctl_params["net.ipv4.tcp_keepalive_time"]="600"
    sysctl_params["net.ipv4.tcp_keepalive_intvl"]="10"
    sysctl_params["net.ipv4.tcp_keepalive_probes"]="6"
    # 内存管理优化
    sysctl_params["vm.swappiness"]="10"
    sysctl_params["vm.dirty_background_ratio"]="5"
    sysctl_params["vm.dirty_ratio"]="10"
    # 文件描述符优化
    sysctl_params["fs.file-max"]="1048576"
    sysctl_params["fs.nr_open"]="1048576"
    # 使用 sed 更新或添加参数
    for key in "${!sysctl_params[@]}"; do
        value="${sysctl_params[$key]}"
        if grep -q "^${key}" /etc/sysctl.conf 2>/dev/null; then
            sed -i "s|^${key}.*|${key} = ${value}|" /etc/sysctl.conf
        else
            echo "${key} = ${value}" >> /etc/sysctl.conf
        fi
    done
    # 应用 sysctl 配置
    sysctl -p 2>/dev/null || true
    # 配置 limits.conf (nofile 限制)
    if [ -f /etc/security/limits.conf ]; then
        # 移除旧的 nofile 配置
        sed -i '/^\*\s*soft\s*nofile/d' /etc/security/limits.conf
        sed -i '/^\*\s*hard\s*nofile/d' /etc/security/limits.conf
        sed -i '/^root\s*soft\s*nofile/d' /etc/security/limits.conf
        sed -i '/^root\s*hard\s*nofile/d' /etc/security/limits.conf
        # 添加新配置
        echo "* soft nofile 1048576" >> /etc/security/limits.conf
        echo "* hard nofile 1048576" >> /etc/security/limits.conf
        echo "root soft nofile 1048576" >> /etc/security/limits.conf
        echo "root hard nofile 1048576" >> /etc/security/limits.conf
        echo "已配置文件描述符限制 (nofile 1048576)"
    fi
    # Alpine 特殊处理
    if [ "$OS" = "alpine" ]; then
        # Alpine 使用 /etc/security/limits.conf 可能不同，配置 /etc/init.d/ 脚本
        if [ -f /etc/inittab ]; then
            echo "ulimit -n 1048576" >> /etc/profile 2>/dev/null || true
        fi
    fi
    echo "性能调优完成！"
    echo "已优化：BBR拥塞控制 | 连接复用 | Keepalive心跳 | 内存管理 | 文件描述符"
    echo "注意：文件描述符限制需重新登录后生效"
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
