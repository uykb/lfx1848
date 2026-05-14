#!/bin/bash

# 严格模式：遇到错误立即退出，使用未定义变量报错，管道失败则整体失败
set -euo pipefail

# 设置 UTF-8 编码，防止终端乱码（兼容旧系统）
# 使用实际测试而非仅依赖 locale -a，确保 locale 真正可用
set_locale() {
    local candidates=("C.UTF-8" "en_US.UTF-8" "zh_CN.UTF-8" "C")
    for loc in "${candidates[@]}"; do
        # 尝试使用该 locale 运行 locale 命令，成功则表示支持
        if LC_ALL="$loc" locale >/dev/null 2>&1; then
            export LANG="$loc"
            export LC_ALL="$loc"
            return 0
        fi
    done
    # 如果都不行，强制使用 C
    export LANG=C
    export LC_ALL=C
}
set_locale

# 常量定义
SCRIPT_URL="https://raw.githubusercontent.com/uykb/lfx1848/main/uykb1.sh"
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/tmp/${SCRIPT_NAME%.sh}.log"

# 日志函数
log_msg() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [${level}] ${msg}" >> "$LOG_FILE" 2>/dev/null || true
    if [[ "$level" == "ERROR" ]]; then
        echo -e "\033[1;31m[${level}] ${msg}\033[0m" >&2
    else
        echo -e "${msg}"
    fi
}

# 检查并自动提权
if [[ "${EUID}" -ne 0 ]]; then
    log_msg "INFO" "检测到非 root 用户，正在尝试提权..."
    if command -v sudo &> /dev/null; then
        if [[ "$0" == /dev/fd/* ]]; then
            # 处理 bash <(curl ...) 管道运行的情况
            TMP_SCRIPT=$(mktemp /tmp/uykb1_XXXXXX.sh)
            trap 'rm -f "${TMP_SCRIPT}"' EXIT
            if command -v curl &> /dev/null; then
                curl -fsSL --connect-timeout 10 --max-time 60 "${SCRIPT_URL}" -o "${TMP_SCRIPT}" || { log_msg "ERROR" "脚本下载失败"; exit 1; }
            elif command -v wget &> /dev/null; then
                wget -qO "${TMP_SCRIPT}" --timeout=60 "${SCRIPT_URL}" || { log_msg "ERROR" "脚本下载失败"; exit 1; }
            else
                log_msg "ERROR" "无法下载脚本，请手动安装 curl 或 wget"
                exit 1
            fi
            if [[ -f "${TMP_SCRIPT}" ]]; then
                sudo bash "${TMP_SCRIPT}"
                exit 0
            else
                log_msg "ERROR" "脚本下载失败"
                exit 1
            fi
        else
            exec sudo "$0" "$@"
        fi
    else
        log_msg "ERROR" "此脚本需要 root 权限运行。请使用 'sudo ./${SCRIPT_NAME}' 运行。"
        exit 1
    fi
fi

DATE="$(date)"

# 检测操作系统类型和包管理器
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="${ID}"
        OS_VERSION="${VERSION_ID:-}"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        OS_VERSION="$(awk '{print $3}' /etc/redhat-release | cut -d. -f1)"
    else
        OS="unknown"
        OS_VERSION=""
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
    elif [[ -d /etc/init.d ]]; then
        INIT_SYS="sysvinit"
    elif command -v rc-service &> /dev/null; then
        INIT_SYS="openrc"
    else
        INIT_SYS="unknown"
    fi
}

detect_os

# 二次确认函数
confirm_action() {
    local action="$1"
    local response
    log_msg "WARN" "警告：即将执行危险操作 - ${action}"
    read -rp "是否确认继续? [y/N]: " response < /dev/tty 2>/dev/null || read -rp "是否确认继续? [y/N]: " response
    if [[ "${response}" =~ ^[Yy]$ ]]; then
        return 0
    else
        log_msg "INFO" "操作已取消"
        return 1
    fi
}

# 验证 IP 地址格式
validate_ip() {
    local ip="$1"
    if [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$ ]] || [[ "${ip}" == "ALL" ]]; then
        return 0
    else
        return 1
    fi
}

# 服务管理函数
service_restart() {
    local svc="$1"
    case "${INIT_SYS}" in
        systemd)
            systemctl restart "${svc}" 2>/dev/null || systemctl restart "${svc}.service" 2>/dev/null || true
            ;;
        openrc)
            rc-service "${svc}" restart 2>/dev/null || true
            ;;
        sysvinit)
            /etc/init.d/"${svc}" restart 2>/dev/null || service "${svc}" restart 2>/dev/null || true
            ;;
    esac
}

# 包安装函数
pkg_install() {
    local packages="$*"
    log_msg "INFO" "正在安装: ${packages}"
    case "${PKG_MGR}" in
        apt)
            apt-get update -y && apt-get install -y "$@" || { log_msg "ERROR" "包安装失败: ${packages}"; return 1; }
            ;;
        dnf)
            dnf install -y "$@" || { log_msg "ERROR" "包安装失败: ${packages}"; return 1; }
            ;;
        yum)
            yum install -y "$@" || { log_msg "ERROR" "包安装失败: ${packages}"; return 1; }
            ;;
        apk)
            apk update && apk add "$@" || { log_msg "ERROR" "包安装失败: ${packages}"; return 1; }
            ;;
        pacman)
            pacman -Sy --noconfirm "$@" || { log_msg "ERROR" "包安装失败: ${packages}"; return 1; }
            ;;
        zypper)
            zypper refresh && zypper install -y "$@" || { log_msg "ERROR" "包安装失败: ${packages}"; return 1; }
            ;;
        *)
            log_msg "ERROR" "未知的包管理器，无法安装: ${packages}"
            return 1
            ;;
    esac
}

# BBR 安装相关函数
bbr_red() {
    printf '\033[1;31m%b\033[0m' "$1"
}

bbr_green() {
    printf '\033[1;32m%b\033[0m' "$1"
}

bbr_yellow() {
    printf '\033[1;33m%b\033[0m' "$1"
}

bbr_info() {
    bbr_green "[Info] "
    printf -- "%s" "$1"
    printf "\n"
}

bbr_warn() {
    bbr_yellow "[Warn] "
    printf -- "%s" "$1"
    printf "\n"
}

bbr_error() {
    bbr_red "[Error] "
    printf -- "%s" "$1"
    printf "\n"
    exit 1
}

bbr_is_64bit() {
    if [[ "$(getconf LONG_BIT)" == "64" ]]; then
        return 0
    else
        return 1
    fi
}

bbr_version_ge() {
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

bbr_check_bbr_status() {
    local param
    param="$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')"
    if [[ "${param}" == "bbr" ]]; then
        return 0
    else
        return 1
    fi
}

bbr_check_kernel_version() {
    local kernel_version
    kernel_version="$(uname -r | cut -d- -f1)"
    if bbr_version_ge "${kernel_version}" 4.9; then
        return 0
    else
        return 1
    fi
}

bbr_sysctl_config() {
    if [[ -f /etc/sysctl.conf ]]; then
        sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
    fi
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
}

bbr_get_latest_version() {
    local latest_version
    local kernel
    local max_retries=3
    local retry=0
    
    while [[ ${retry} -lt ${max_retries} ]]; do
        latest_version=($(wget -qO- --timeout=30 https://kernel.ubuntu.com/~kernel-ppa/mainline/ 2>/dev/null | awk -F'\"v' '/v[4-9]\./{print $2}' | cut -d/ -f1 | grep -v -- '-' | sort -V))
        if [[ ${#latest_version[@]} -gt 0 ]]; then
            break
        fi
        retry=$((retry + 1))
        log_msg "WARN" "获取内核版本失败，重试 ${retry}/${max_retries}..."
        sleep 2
    done
    
    [[ ${#latest_version[@]} -eq 0 ]] && bbr_error "获取最新内核版本失败"
    
    local kernel_arr=()
    local i
    for i in "${latest_version[@]}"; do
        if bbr_version_ge "${i}" 5.15; then
            kernel_arr+=("${i}")
        fi
    done
    
    if [[ ${#kernel_arr[@]} -gt 0 ]]; then
        kernel="${kernel_arr[${#kernel_arr[@]}-1]}"
    else
        kernel="${latest_version[${#latest_version[@]}-1]}"
    fi
    
    local deb_name modules_deb_name
    if bbr_is_64bit; then
        deb_name="$(wget -qO- --timeout=30 "https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/" 2>/dev/null | grep "linux-image" | grep "generic" | awk -F'\">' '/amd64\.deb/{print $2}' | cut -d'<' -f1 | head -1)"
        deb_kernel_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${deb_name}"
        deb_kernel_name="linux-image-${kernel}-amd64.deb"
        modules_deb_name="$(wget -qO- --timeout=30 "https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/" 2>/dev/null | grep "linux-modules" | grep "generic" | awk -F'\">' '/amd64\.deb/{print $2}' | cut -d'<' -f1 | head -1)"
        deb_kernel_modules_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${modules_deb_name}"
        deb_kernel_modules_name="linux-modules-${kernel}-amd64.deb"
    else
        deb_name="$(wget -qO- --timeout=30 "https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/" 2>/dev/null | grep "linux-image" | grep "generic" | awk -F'\">' '/i386\.deb/{print $2}' | cut -d'<' -f1 | head -1)"
        deb_kernel_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${deb_name}"
        deb_kernel_name="linux-image-${kernel}-i386.deb"
        modules_deb_name="$(wget -qO- --timeout=30 "https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/" 2>/dev/null | grep "linux-modules" | grep "generic" | awk -F'\">' '/i386\.deb/{print $2}' | cut -d'<' -f1 | head -1)"
        deb_kernel_modules_url="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${kernel}/${modules_deb_name}"
        deb_kernel_modules_name="linux-modules-${kernel}-i386.deb"
    fi
    [[ -z "${deb_name}" ]] && bbr_error "获取内核包名失败"
}

bbr_install_kernel_debian() {
    bbr_info "获取最新内核版本..."
    bbr_get_latest_version
    if [[ -n "${modules_deb_name:-}" ]]; then
        wget -c -t3 -T60 -O "${deb_kernel_modules_name}" "${deb_kernel_modules_url}" || bbr_error "下载内核模块包失败"
    fi
    wget -c -t3 -T60 -O "${deb_kernel_name}" "${deb_kernel_url}" || bbr_error "下载内核包失败"
    dpkg -i "${deb_kernel_modules_name}" "${deb_kernel_name}" || bbr_error "安装内核失败"
    rm -f "${deb_kernel_modules_name}" "${deb_kernel_name}"
    /usr/sbin/update-grub 2>/dev/null || true
}

bbr_install_kernel_centos6() {
    command -v perl &> /dev/null || pkg_install perl
    local rpm_kernel_url="https://dl.lamp.sh/files/"
    local rpm_kernel_name rpm_kernel_devel_name
    if bbr_is_64bit; then
        rpm_kernel_name="kernel-ml-4.18.20-1.el6.elrepo.x86_64.rpm"
        rpm_kernel_devel_name="kernel-ml-devel-4.18.20-1.el6.elrepo.x86_64.rpm"
    else
        rpm_kernel_name="kernel-ml-4.18.20-1.el6.elrepo.i686.rpm"
        rpm_kernel_devel_name="kernel-ml-devel-4.18.20-1.el6.elrepo.i686.rpm"
    fi
    wget -c -t3 -T60 -O "${rpm_kernel_name}" "${rpm_kernel_url}${rpm_kernel_name}" || bbr_error "下载内核失败"
    wget -c -t3 -T60 -O "${rpm_kernel_devel_name}" "${rpm_kernel_url}${rpm_kernel_devel_name}" || bbr_error "下载内核devel失败"
    rpm -ivh "${rpm_kernel_name}" || bbr_error "安装内核失败"
    rpm -ivh "${rpm_kernel_devel_name}" || bbr_error "安装内核devel失败"
    rm -f "${rpm_kernel_name}" "${rpm_kernel_devel_name}"
    [[ ! -f "/boot/grub/grub.conf" ]] && bbr_error "/boot/grub/grub.conf 不存在"
    sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
}

bbr_install_kernel_centos7() {
    local rpm_kernel_url="https://dl.lamp.sh/kernel/el7/"
    local rpm_kernel_name rpm_kernel_devel_name
    if bbr_is_64bit; then
        rpm_kernel_name="kernel-ml-5.15.60-1.el7.x86_64.rpm"
        rpm_kernel_devel_name="kernel-ml-devel-5.15.60-1.el7.x86_64.rpm"
    else
        bbr_error "不支持32位系统"
    fi
    wget -c -t3 -T60 -O "${rpm_kernel_name}" "${rpm_kernel_url}${rpm_kernel_name}" || bbr_error "下载内核失败"
    wget -c -t3 -T60 -O "${rpm_kernel_devel_name}" "${rpm_kernel_url}${rpm_kernel_devel_name}" || bbr_error "下载内核devel失败"
    rpm -ivh "${rpm_kernel_name}" || bbr_error "安装内核失败"
    rpm -ivh "${rpm_kernel_devel_name}" || bbr_error "安装内核devel失败"
    rm -f "${rpm_kernel_name}" "${rpm_kernel_devel_name}"
    /usr/sbin/grub2-set-default 0
}

bbr_install_kernel() {
    case "${OS}" in
        centos)
            if [[ -f /etc/redhat-release ]]; then
                local centos_ver
                centos_ver="$(awk '{print $NF}' /etc/redhat-release | grep -oE '[0-9]+' | head -1)"
                if [[ "${centos_ver}" -eq 6 ]]; then
                    bbr_install_kernel_centos6
                elif [[ "${centos_ver}" -eq 7 ]]; then
                    bbr_install_kernel_centos7
                else
                    bbr_warn "CentOS ${centos_ver} 使用官方源安装内核..."
                    if [[ "${PKG_MGR}" == "dnf" ]]; then
                        dnf install -y kernel kernel-modules || bbr_error "安装内核失败"
                    else
                        yum install -y kernel kernel-modules || bbr_error "安装内核失败"
                    fi
                    grub2-set-default 0 2>/dev/null || true
                fi
            fi
            ;;
        rhel|rocky|almalinux|fedora)
            bbr_info "使用官方源安装最新内核..."
            if [[ "${PKG_MGR}" == "dnf" ]]; then
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
            update-extlinux 2>/dev/null || true
            ;;
        arch)
            bbr_info "Arch Linux 系统安装最新内核..."
            pkg_install linux linux-headers
            grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
            ;;
        *)
            bbr_error "不支持的操作系统: ${OS}"
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
    local is_reboot
    read -rp "是否现在重启系统? [y/n]: " is_reboot < /dev/tty 2>/dev/null || read -rp "是否现在重启系统? [y/n]: " is_reboot
    if [[ "${is_reboot}" == "y" || "${is_reboot}" == "Y" ]]; then
        reboot
    else
        bbr_info "已取消重启，请手动重启以应用 BBR"
    fi
}

# Docker 安装函数（提取重复代码）
install_docker_official() {
    log_msg "INFO" "使用 Docker 官方脚本安装..."
    curl -fsSL --connect-timeout 10 --max-time 120 https://get.docker.com -o /tmp/get-docker.sh || { log_msg "ERROR" "下载 Docker 安装脚本失败"; return 1; }
    sh /tmp/get-docker.sh || { log_msg "ERROR" "Docker 安装失败"; rm -f /tmp/get-docker.sh; return 1; }
    rm -f /tmp/get-docker.sh
}

# Hysteria2 安装相关函数
hy2_generate_password() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 18
    else
        dd if=/dev/urandom bs=18 count=1 status=none | base64 2>/dev/null || head -c 18 /dev/urandom | base64
    fi
}

hy2_generate_config() {
    local password="$1"
    local port="${2:-40443}"
    cat << EOF
listen: :${port}

# 使用自签名证书
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${password}

masquerade:
  type: proxy
  proxy:
    url: https://odoo.com/
    rewriteHost: true
EOF
}

hy2_generate_systemd_service() {
    cat << 'EOF'
[Unit]
Description=Hysteria 2 Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=512000

[Install]
WantedBy=multi-user.target
EOF
}

hy2_generate_openrc_service() {
    cat << 'EOF'
#!/sbin/openrc-run

name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/${name}.pid"
command_background="yes"

depend() {
    need networking
}
EOF
}

hy2_install() {
    log_msg "INFO" "正在安装 Hysteria2..."
    
    # 安装依赖
    case "${PKG_MGR}" in
        apt)
            pkg_install wget curl openssl
            ;;
        dnf|yum)
            pkg_install wget curl openssl
            ;;
        apk)
            pkg_install wget curl openssl
            ;;
        pacman)
            pkg_install wget curl openssl
            ;;
        *)
            log_msg "ERROR" "不支持的包管理器"
            return 1
            ;;
    esac
    
    # 生成随机密码
    local hy2_password
    hy2_password="$(hy2_generate_password)"
    if [[ -z "${hy2_password}" ]]; then
        log_msg "ERROR" "生成密码失败"
        return 1
    fi
    
    local hy2_port="40443"
    log_msg "INFO" "端口: ${hy2_port}"
    log_msg "INFO" "密码: ${hy2_password}"
    
    # 创建目录
    mkdir -p /etc/hysteria
    
    # 下载 Hysteria2 二进制文件
    log_msg "INFO" "正在下载 Hysteria2..."
    local arch="amd64"
    if [[ "$(uname -m)" == "aarch64" ]]; then
        arch="arm64"
    fi
    
    wget -O /usr/local/bin/hysteria "https://download.hysteria.network/app/latest/hysteria-linux-${arch}" --no-check-certificate --timeout=60 || {
        log_msg "ERROR" "下载 Hysteria2 失败"
        return 1
    }
    chmod +x /usr/local/bin/hysteria
    
    # 生成自签名证书
    log_msg "INFO" "正在生成 SSL 证书..."
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/hysteria/server.key \
        -out /etc/hysteria/server.crt \
        -subj "/CN=odoo.com" -days 36500 2>/dev/null || {
        log_msg "ERROR" "生成 SSL 证书失败"
        return 1
    }
    
    # 写入配置文件
    hy2_generate_config "${hy2_password}" "${hy2_port}" > /etc/hysteria/config.yaml
    
    # 配置自启动
    case "${INIT_SYS}" in
        systemd)
            hy2_generate_systemd_service > /etc/systemd/system/hysteria.service
            systemctl daemon-reload 2>/dev/null || true
            systemctl enable hysteria 2>/dev/null || true
            service_restart hysteria
            ;;
        openrc)
            hy2_generate_openrc_service > /etc/init.d/hysteria
            chmod +x /etc/init.d/hysteria
            rc-update add hysteria 2>/dev/null || true
            rc-service hysteria start 2>/dev/null || true
            ;;
        sysvinit)
            hy2_generate_openrc_service > /etc/init.d/hysteria
            chmod +x /etc/init.d/hysteria
            service hysteria start 2>/dev/null || true
            ;;
    esac
    
    # 显示配置信息
    echo ""
    log_msg "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_msg "INFO" "Hysteria2 安装完成!"
    log_msg "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_msg "INFO" "服务器地址: 服务器IP:${hy2_port}"
    log_msg "INFO" "密码: ${hy2_password}"
    log_msg "INFO" "TLS SNI: odoo.com"
    log_msg "INFO" "端口: ${hy2_port}"
    log_msg "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_msg "INFO" "配置文件: /etc/hysteria/config.yaml"
    log_msg "INFO" "证书文件: /etc/hysteria/server.crt"
    log_msg "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_msg "INFO" "客户端配置: 选择自定义协议，填入上述信息"
    log_msg "INFO" "查看状态: systemctl status hysteria (systemd)"
    log_msg "INFO" "          rc-service hysteria status (openrc)"
    log_msg "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 显示菜单
show_menu() {
    echo -e "  
------------------------------------------------------------------------------                                        
项 目 地 址   https://github.com/uykb/lfx1848 
当前时间：${DATE}
检测到系统: ${OS} (${PKG_MGR} 包管理器, ${INIT_SYS} 初始化系统)
-------------------------多功能一键安装脚本---------------------------
        1. 升级系统内核/源
        2. 安装 BBR
        3. 性能调优
        4. 限制IP登录服务器
        5. 安装 Docker
        6. 快速清理 Linux 资源
        7. 安装 Hysteria2
        0. 退出脚本
------------------------------------------------------------------------------
"
    echo "请输入数字进行选择 并 回车确认"
}

# 主菜单循环函数
main_menu() {
    while true; do
        show_menu
        read -rp "请选择: " chosen < /dev/tty 2>/dev/null || read -rp "请选择: " chosen

        if [[ "${chosen}" == "1" ]]; then
        case "${OS}" in
            debian)
                log_msg "WARN" "警告：升级到 Debian sid (unstable) 可能导致系统不稳定！"
                if ! confirm_action "升级到 Debian unstable 分支"; then
                    continue
                fi
                log_msg "INFO" "正在升级到 Debian sid..."
                apt-get update -y && apt-get upgrade -y
                echo "deb http://deb.debian.org/debian unstable main contrib non-free" > /etc/apt/sources.list
                apt-get update -y && apt-get upgrade -y
                pkg_install linux-image-cloud-amd64
                apt-get autoremove -y && reboot
                ;;
            ubuntu)
                log_msg "INFO" "正在升级 Ubuntu 系统..."
                apt-get update -y && apt-get upgrade -y
                do-release-upgrade -y || log_msg "WARN" "请手动执行 do-release-upgrade"
                ;;
            alpine)
                log_msg "INFO" "正在升级 Alpine 系统..."
                apk update && apk upgrade
                log_msg "INFO" "Alpine 升级完成，如需升级大版本请修改 /etc/apk/repositories"
                ;;
            centos|rhel|rocky|almalinux)
                log_msg "INFO" "正在升级 RHEL 系系统..."
                if [[ "${PKG_MGR}" == "dnf" ]]; then
                    dnf update -y && dnf upgrade -y
                else
                    yum update -y && yum upgrade -y
                fi
                ;;
            fedora)
                log_msg "INFO" "正在升级 Fedora 系统..."
                dnf upgrade --refresh -y
                ;;
            arch)
                log_msg "INFO" "正在升级 Arch Linux..."
                pacman -Syu --noconfirm
                ;;
            *)
                log_msg "WARN" "当前系统 ${OS} 不支持此功能，请手动升级"
                ;;
        esac
    elif [[ "${chosen}" == "2" ]]; then
        log_msg "INFO" "正在安装 BBR..."
        # 安装必要依赖
        case "${PKG_MGR}" in
            apt|dnf|yum|apk|pacman)
                pkg_install wget ca-certificates
                ;;
        esac
        bbr_install
    elif [[ "${chosen}" == "3" ]]; then
        log_msg "INFO" "正在进行全面性能调优..."
        # 备份原始配置
        if [[ -f /etc/sysctl.conf ]]; then
            cp /etc/sysctl.conf "/etc/sysctl.conf.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
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
        local key value
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
        if [[ -f /etc/security/limits.conf ]]; then
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
            log_msg "INFO" "已配置文件描述符限制 (nofile 1048576)"
        fi
        # Alpine 特殊处理
        if [[ "${OS}" == "alpine" ]]; then
            echo "ulimit -n 1048576" >> /etc/profile 2>/dev/null || true
        fi
        log_msg "INFO" "性能调优完成！"
        log_msg "INFO" "已优化：BBR拥塞控制 | 连接复用 | Keepalive心跳 | 内存管理 | 文件描述符"
        log_msg "INFO" "注意：文件描述符限制需重新登录后生效"
    elif [[ "${chosen}" == "4" ]]; then
        log_msg "INFO" "请输入允许登录的IP地址（多个IP用空格分隔）："
        local allow_ips_str
        read -rp "IP地址: " allow_ips_str < /dev/tty 2>/dev/null || read -rp "IP地址: " allow_ips_str
        local -a allow_ips=(${allow_ips_str})
        if [[ ${#allow_ips[@]} -eq 0 ]]; then
            log_msg "ERROR" "IP地址不能为空"
            continue
        fi
        # 验证 IP 格式
        local ip
        for ip in "${allow_ips[@]}"; do
            if ! validate_ip "${ip}"; then
                log_msg "ERROR" "无效的IP地址格式: ${ip}"
                continue 2
            fi
        done
        # 写入 hosts.allow
        > /etc/hosts.allow
        for ip in "${allow_ips[@]}"; do
            echo "sshd:${ip}:allow" >> /etc/hosts.allow
        done
        # 写入 hosts.deny
        echo "sshd:ALL" > /etc/hosts.deny
        # 重启 SSH 服务
        case "${OS}" in
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
        log_msg "INFO" "已配置仅允许IP ${allow_ips[*]} 登录SSH"
    elif [[ "${chosen}" == "5" ]]; then
        log_msg "INFO" "正在安装 Docker..."
        case "${OS}" in
            alpine)
                pkg_install docker docker-cli-compose
                service_restart docker
                rc-update add docker default 2>/dev/null || true
                ;;
            debian|ubuntu|centos|rhel|rocky|almalinux|fedora)
                install_docker_official
                ;;
            arch)
                pkg_install docker
                service_restart docker
                systemctl enable docker 2>/dev/null || true
                ;;
            *)
                install_docker_official
                ;;
        esac
        usermod -aG docker "$(whoami)" 2>/dev/null || true
        log_msg "INFO" "Docker 安装完成，请重新登录以应用 docker 用户组权限"
    elif [[ "${chosen}" == "6" ]]; then
        log_msg "INFO" "开始快速清理 Linux 资源..."
        # 清理包管理器缓存
        case "${PKG_MGR}" in
            apt)
                log_msg "INFO" "[Debian/Ubuntu] 清理 apt 缓存和孤立包..."
                apt-get autoremove -y 2>/dev/null || true
                apt-get clean 2>/dev/null || true
                ;;
            dnf)
                log_msg "INFO" "[RHEL/Fedora] 清理 dnf 缓存..."
                dnf clean all 2>/dev/null || true
                dnf autoremove -y 2>/dev/null || true
                ;;
            yum)
                log_msg "INFO" "[CentOS] 清理 yum 缓存..."
                yum clean all 2>/dev/null || true
                yum autoremove -y 2>/dev/null || true
                ;;
            apk)
                log_msg "INFO" "[Alpine] 清理 apk 缓存..."
                rm -rf /var/cache/apk/* 2>/dev/null || true
                ;;
            pacman)
                log_msg "INFO" "[Arch] 清理 pacman 缓存..."
                if command -v paccache &> /dev/null; then
                    paccache -rk1 2>/dev/null || true
                else
                    pacman -Sc --noconfirm 2>/dev/null || true
                fi
                pacman -Rns "$(pacman -Qdtq 2>/dev/null)" --noconfirm 2>/dev/null || true
                ;;
            zypper)
                log_msg "INFO" "[openSUSE] 清理 zypper 缓存..."
                zypper clean --all 2>/dev/null || true
                ;;
        esac
        # 清理系统日志
        if command -v journalctl &> /dev/null; then
            log_msg "INFO" "清理 systemd 日志 (保留100M)..."
            journalctl --vacuum-size=100M 2>/dev/null || true
        fi
        # Alpine 日志清理
        if [[ -d /var/log ]]; then
            find /var/log -type f -name "*.log" -size +50M -exec truncate -s 0 {} \; 2>/dev/null || true
        fi
        # 清理临时文件
        log_msg "INFO" "清理 /tmp 和 /var/tmp 中超过7天的文件..."
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
        # 清理缩略图缓存
        rm -rf /root/.cache/thumbnails/* 2>/dev/null || true
        # 清理崩溃报告
        rm -rf /var/crash/* 2>/dev/null || true
        # 清理 Docker 资源
        if command -v docker &> /dev/null && docker info &> /dev/null; then
            log_msg "INFO" "清理 Docker 悬空镜像和停止的容器..."
            docker system prune -f 2>/dev/null || true
        fi
        log_msg "INFO" "清理完成！"
        df -h / 2>/dev/null || true
    elif [[ "${chosen}" == "7" ]]; then
        hy2_install
    elif [[ "${chosen}" == "0" ]]; then
        log_msg "INFO" "退出脚本"
        exit 0 
    else
        log_msg "INFO" "输入命令有误，正在尝试更新脚本..."
        if command -v wget &> /dev/null; then
            wget -N --no-check-certificate "${SCRIPT_URL}" && chmod +x "${SCRIPT_NAME}" && exec "./${SCRIPT_NAME}"
        elif command -v curl &> /dev/null; then
            curl -fsSL "${SCRIPT_URL}" -o "${SCRIPT_NAME}" && chmod +x "${SCRIPT_NAME}" && exec "./${SCRIPT_NAME}"
        else
            log_msg "ERROR" "未找到 wget 或 curl，无法自动更新脚本"
            exit 1
        fi
    fi
    
    # 执行完成后返回菜单
    echo ""
    log_msg "INFO" "按回车键返回主菜单..."
    read -r < /dev/tty 2>/dev/null || read -r
    done
}

# 启动主菜单
main_menu
