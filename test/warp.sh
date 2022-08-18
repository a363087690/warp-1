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

main=$(uname -r | awk -F . '{print $1}')
minor=$(uname -r | awk -F . '{print $2}')
OSID=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
VIRT=$(systemd-detect-virt)
TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')

# Wgcf 去除IPv4/IPv6
wg1="sed -i '/0\.0\.0\.0\/0/d' /etc/wireguard/wgcf.conf"
wg2="sed -i '/\:\:\/0/d' /etc/wireguard/wgcf.conf"
# Wgcf Endpoint
wg3="sed -i 's/engage.cloudflareclient.com/162.159.193.10/g' /etc/wireguard/wgcf.conf"
wg4="sed -i 's/engage.cloudflareclient.com/[2606:4700:d0::a29f:c001]/g' /etc/wireguard/wgcf.conf"
# Wgcf DNS Servers
wg5="sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844/g' /etc/wireguard/wgcf.conf"
wg6="sed -i 's/1.1.1.1/2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,8.8.8.8,8.8.4.4/g' /etc/wireguard/wgcf.conf"
# Wgcf 允许外部IP地址
wg7='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
wg8='sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
wg9='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'

if [[ -z $(type -P curl) ]]; then
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl
fi

archAffix(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

checkv4v6(){
    v6=$(curl -s6m8 https://ip.gs -k)
    v4=$(curl -s4m8 https://ip.gs -k)
}

wgcfv4(){
    checkwgcf
    if [[ $wgcfv4 =~ on|plus ]] || [[ $wgcfv6 =~ on|plus ]]; then
        stopwgcf
        checkv4v6
    else
        checkv4v6
    fi

    if [[ -n $v4 && -z $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4)"
            stopwgcf
            switchconf
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg2
            wgcf4=$wg3
            wgcfconf
            wgcfcheck
        else
            yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4)"
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg2
            wgcf4=$wg3
            installwgcf
        fi
    fi
    if [[ -z $v4 && -n $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg6
            wgcf2=$wg2
            wgcf3=$wg4
            wgcfconf
            wgcfcheck
        else
            yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg6
            wgcf2=$wg2
            wgcf3=$wg4
            installwgcf
        fi
    fi
    if [[ -n $v4 && -n $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg2
            wgcfconf
            wgcfcheck
        else
            yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg2
            installwgcf
        fi
    fi
}

wgcfv6(){
    checkwgcf
    if [[ $wgcfv4 =~ on|plus ]] || [[ $wgcfv6 =~ on|plus ]]; then
        stopwgcf
        checkv4v6
    else
        checkv4v6
    fi
    
    if [[ -n $v4 && -z $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局单栈模式 (原生IPv4 + WARP IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg5
            wgcf2=$wg1
            wgcf3=$wg3
            wgcfconf
            wgcfcheck
        else
            yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (原生IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg1
            wgcf3=$wg3
            installwgcf
        fi
    fi
    if [[ -z $v4 && -n $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg6
            wgcf2=$wg8
            wgcf3=$wg1
            wgcf4=$wg4
            wgcfconf
            wgcfcheck
        else
            yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv6)"
            wgcf1=$wg6
            wgcf2=$wg8
            wgcf3=$wg1
            wgcf4=$wg4
            installwgcf
        fi
    fi
    if [[ -n $v4 && -n $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg5
            wgcf2=$wg9
            wgcfconf
            wgcfcheck
        else
            yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg9
            installwgcf
        fi
    fi
}

wgcfv4v6(){
    checkwgcf
    if [[ $wgcfv4 =~ on|plus ]] || [[ $wgcfv6 =~ on|plus ]]; then
        stopwgcf
        checkv4v6
    else
        checkv4v6
    fi
    
    if [[ -n $v4 && -z $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg3
            wgcfconf
            wgcfcheck
        else
            yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg3
            installwgcf
        fi
    fi
    if [[ -z $v4 && -n $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg6
            wgcf2=$wg8
            wgcf3=$wg4
            wgcfconf
            wgcfcheck
        else
            yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg6
            wgcf2=$wg8
            wgcf3=$wg4
            installwgcf
        fi
    fi
    if [[ -n $v4 && -n $v6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + WARP IPv6)"
            stopwgcf
            switchconf
            wgcf1=$wg5
            wgcf2=$wg9
            wgcfconf
            wgcfcheck
        else
            yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg9
            installwgcf
        fi
    fi
}

installwgcf(){
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils
        if [[ $OSID == 9 ]] && [[ -z $(type -P resolvconf) ]]; then
            wget -N https://raw.githubusercontent.com/taffychan/warp/main/files/resolvconf -O /usr/sbin/resolvconf
            chmod +x /usr/sbin/resolvconf
        fi
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl lsb-release bc htop screen python3 inetutils-ping
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop screen python3 inetutils-ping
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    
    if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]] || [[ $VIRT =~ lxc|openvz ]]; then
        wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/files/wireguard-go/wireguard-go-$(archAffix) -O /usr/bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi

    initwgcf
    wgcfreg
    checkmtu

    cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf >/dev/null 2>&1
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml >/dev/null 2>&1

    wgcfconf

    systemctl enable wg-quick@wgcf >/dev/null 2>&1
    wgcfcheck
}

switchconf(){
    rm -rf /etc/wireguard/wgcf.conf
    cp -f /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1
}

wgcfconf(){
    echo $wgcf1 | sh
    echo $wgcf2 | sh
    echo $wgcf3 | sh
    echo $wgcf4 | sh
}

checkmtu(){
    yellow "正在检测并设置MTU最佳值, 请稍等..."
    checkv4v6
    MTUy=1500
    MTUc=10
    if [[ -n ${v6} && -z ${v4} ]]; then
        ping='ping6'
        IP1='2606:4700:4700::1001'
        IP2='2001:4860:4860::8888'
    else
        ping='ping'
        IP1='1.1.1.1'
        IP2='8.8.8.8'
    fi
    while true; do
        if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
            MTUc=1
            MTUy=$((${MTUy} + ${MTUc}))
        else
            MTUy=$((${MTUy} - ${MTUc}))
            if [[ ${MTUc} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTUy} -le 1360 ]]; then
            MTUy='1360'
            break
        fi
    done
    MTU=$((${MTUy} - 80))
    sed -i "s/MTU.*/MTU = $MTU/g" wgcf-profile.conf
    green "MTU 最佳值=$MTU 已设置完毕"
}

checkwgcf(){
    wgcfv6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    wgcfv4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

wgcfcheck(){
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    yellow "正在启动Wgcf-WARP"
    checkwgcf
    while [ $i -le 4 ]; do let i++
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        checkwgcf
        if [[ $warpv4 =~ on|plus ]] ||[[ $warpv6 =~ on|plus ]]; then
            green "Wgcf-WARP 已启动成功！"
            break
        else
            red "Wgcf-WARP 启动失败！"
        fi
        checkwgcf
        if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
            green "安装Wgcf-WARP失败，建议如下："
            yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分VPS系统极度精简，相关依赖需自行安装后再尝试"
            yellow "3. 查看https://www.cloudflarestatus.com/,你当前VPS就近区域可能处于黄色的【Re-routed】状态"
            exit 1
        fi
    done
}

switchwgcf(){
    checkwgcf
    if [[ $wgcfv4 =~ on|plus ]] || [[ $wgcfv6 =~ on|plus ]]; then
        startwgcf
        green "Wgcf-WARP 已启动成功！"
    fi
    if [[ ! $wgcfv4 =~ on|plus ]] || [[ ! $wgcfv6 =~ on|plus ]]; then
        stopwgcf
        green "Wgcf-WARP 已停止成功！"
    fi
}

startwgcf(){
    wg-quick up wgcf >/dev/null 2>&1
    systemctl enable wg-quick@wgcf >/dev/null 2>&1
}

stopwgcf(){
    wg-quick down wgcf >/dev/null 2>&1
    systemctl disable wg-quick@wgcf >/dev/null 2>&1
}

uninstallwgcf(){
    wg-quick down wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null
    ${PACKAGE_UNINSTALL[int]} wireguard-tools wireguard-dkms
    if [[ -z $(type -P wireproxy) ]]; then
        rm -f /usr/local/bin/wgcf
        rm -f /etc/wireguard/wgcf-account.toml
    fi
    rm -f /etc/wireguard/wgcf.conf
    rm -f /usr/bin/wireguard-go
    if [[ -e /etc/gai.conf ]]; then
        sed -i '/^precedence[ ]*::ffff:0:0\/96[ ]*100/d' /etc/gai.conf
    fi
    green "Wgcf-WARP 已彻底卸载成功!"
}

menu(){
    clear
    echo "#############################################################"
    echo -e "#                    ${RED} WARP  一键安装脚本${PLAIN}                    #"
    echo -e "# ${GREEN}作者${PLAIN}: taffychan                                           #"
    echo -e "# ${GREEN}GitHub${PLAIN}: https://github.com/taffychan                      #"
    echo "#############################################################"
    echo -e ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Wgcf-WARP 全局单栈模式 ${YELLOW}(WARP IPv4)${PLAIN} | ${GREEN}6.${PLAIN} 安装 WARP-Cli 全局模式 ${YELLOW}(WARP IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 Wgcf-WARP 全局单栈模式 ${YELLOW}(WARP IPv6)${PLAIN} | ${GREEN}7.${PLAIN} 安装 WARP-Cli 代理模式"
    echo -e " ${GREEN}3.${PLAIN} 安装 Wgcf-WARP 全局双栈模式             | ${GREEN}8.${PLAIN} 修改 WARP-Cli 代理模式连接端口"
    echo -e " ${GREEN}4.${PLAIN} 开启或关闭 Wgcf-WARP                    | ${GREEN}9.${PLAIN} 开启或关闭 WARP-Cli 代理模式"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}                          | ${GREEN}10.${PLAIN} ${RED}卸载 WARP-Cli${PLAIN}"
    echo " ----------------------------------------------------------------------------------"
    echo -e " ${GREEN}11.${PLAIN} 安装 Wireproxy-WARP 代理模式           | ${GREEN}15.${PLAIN} 获取 WARP+ 账户流量"
    echo -e " ${GREEN}12.${PLAIN} 修改 Wireproxy-WARP 代理模式连接端口   | ${GREEN}16.${PLAIN} 切换 WARP 账户类型"
    echo -e " ${GREEN}13.${PLAIN} 开启或关闭 Wireproxy-WARP 代理模式     | ${GREEN}17.${PLAIN} 获取解锁 Netflix 的 WARP IP"
    echo -e " ${GREEN}14.${PLAIN} ${RED}卸载 Wireproxy-WARP 代理模式${PLAIN}           | ${GREEN}0.${PLAIN} 退出脚本"
    echo -e ""
    showIP
    echo -e ""
    read -rp "请输入选项 [0-17]：" menuChoice
    case $menuChoice in
        1) wgcfv4 ;;
        2) wgcfv6 ;;
        3) wgcfv4v6 ;;
        4) switchwgcf ;;
        5) uninstallwgcf ;;
        6) warpcli=2 && installCli ;;
        7) warpcli=1 && installCli ;;
        8) warpcli_changeport ;;
        9) switchCli ;;
        10) uninstallCli ;;
        11) installWireProxy ;;
        12) wireproxy_changeport ;;
        13) switchWireProxy ;;
        14) uninstallWireProxy ;;
        15) warpup ;;
        16) warpsw ;;
        17) warpnf ;;
        *) red "请输入正确的选项 [0-17]！" && exit 1 ;;
    esac
}

menu