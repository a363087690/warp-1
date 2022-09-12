#!/bin/bash

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "注意: 请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "目前你的VPS的操作系统暂未支持！" && exit 1

archAffix(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

if [[ ! -f /usr/local/bin/nf ]]; then
    wget https://cdn.jsdelivr.net/gh/taffychan/warp/netflix/verify/nf_linux_$(archAffix) -O /usr/local/bin/nf
    chmod +x /usr/local/bin/nf
fi

wgcf4(){
    wgcfv4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ ! $wgcfv4 =~ on|plus ]]; then
        red "Wgcf-WARP的IPv4未正常配置，请在脚本中安装Wgcf-WARP全局模式！"
        exit 1
    fi
}

wgcf6(){
    wgcfv6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ ! $wgcfv6 =~ on|plus ]]; then
        red "Wgcf-WARP的IPv6未正常配置，请在脚本中安装Wgcf-WARP全局模式！"
        exit 1
    fi
}

wgcfd(){
    wgcfv4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    wgcfv6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ ! $wgcfv4 =~ on|plus || ! $wgcfv6 =~ on|plus ]]; then
        red "Wgcf-WARP的IPv4和IPv6未正常配置，请在脚本中安装Wgcf-WARP全局模式！"
        exit 1
    fi
}

cliquan(){
    warpstat=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k --interface CloudflareWARP | grep warp | cut -d= -f2)
}

clisocks(){
    cliport=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
    warpstat=$(curl -sx socks5h://localhost:$cliport https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
}

wireproxy(){
    wireport=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")
    warpstat=$(curl -sx socks5h://localhost:$wireport https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
}

menu(){
    yellow "需要使用什么方式来使用WARP的Netflix IP"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} Wgcf-WARP 全局单栈模式 ${YELLOW}(WARP IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} Wgcf-WARP 全局单栈模式 ${YELLOW}(WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} Wgcf-WARP 全局双栈模式 ${YELLOW}(WARP IPv4 + WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} WARP-Cli 全局模式 ${YELLOW}(WARP IPv4)${PLAIN}"
    echo -e " ${GREEN}5.${PLAIN} WARP-Cli 代理模式"
    echo -e " ${GREEN}6.${PLAIN} WireProxy-WARP 代理模式"
    echo ""
    read -rp "请选择客户端 [1-6]: " clientInput
    case "$clientInput" in
        * ) exit 1 ;;
    esac
}

menu