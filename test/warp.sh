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

check_quota(){
    if [[ "$CHECK_TYPE" = 1 ]]; then
        QUOTA=$(grep -oP 'Quota: \K\d+' <<< $ACCOUNT)
    else
        ACCESS_TOKEN=$(grep 'access_token' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
        DEVICE_ID=$(grep 'device_id' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
        API=$(curl -s "https://api.cloudflareclient.com/v0a884/reg/$DEVICE_ID" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $ACCESS_TOKEN")
        QUOTA=$(grep -oP '"quota":\K\d+' <<< $API)
    fi
    [[ $QUOTA -gt 10000000000000 ]] && QUOTA="$(echo "scale=2; $QUOTA/1000000000000" | bc) TB" || QUOTA="$(echo "scale=2; $QUOTA/1000000000" | bc) GB"
}

checktun(){
    if [[ ! $TUN =~ "in bad state"|"处于错误状态"|"ist in schlechter Verfassung" ]]; then
        if [[ $VIRT == lxc ]]; then
            if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
                red "检测到未开启TUN模块, 请到VPS后台控制面板处开启"
                exit 1
            else
                return 0
            fi
        elif [[ $VIRT == "openvz" ]]; then
            wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/files/tun.sh && bash tun.sh
        else
            red "检测到未开启TUN模块, 请到VPS后台控制面板处开启"
            exit 1
        fi
    fi
}

checkv4v6(){
    v6=$(curl -s6m8 https://ip.gs -k)
    v4=$(curl -s4m8 https://ip.gs -k)
}

initwgcf(){
    wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/files/wgcf/wgcf_2.2.15_linux_$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf
}

wgcfreg(){
    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
    fi

    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP注册账号, 如提示429 Too Many Requests错误请耐心等待重试注册即可"
        wgcf register --accept-tos
        sleep 5
    done
    chmod +x wgcf-account.toml

    wgcf generate
    chmod +x wgcf-profile.conf
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
    [[ $SYSTEM == "CentOS" ]] && [[ ${OSID} -lt 7 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 7及以上版本的系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ${OSID} -lt 10 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Debian 10及以上版本的系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && [[ ${OSID} -lt 29 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Fedora 29及以上版本的系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ${OSID} -lt 18 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Ubuntu 16.04及以上版本的系统" && exit 1

    checktun

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

installcli(){
    [[ $SYSTEM == "CentOS" ]] && [[ ! ${OSID} =~ 8 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 8系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ! ${OSID} =~ 9|10|11 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Debian 9-11系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && yellow "当前系统版本：${CMD} \nWARP-Cli暂时不支持Fedora系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ! ${OSID} =~ 16|18|20|22 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Ubuntu 16.04/18.04/20.04/22.04系统" && exit 1
    
    [[ ! $(archAffix) == "amd64" ]] && red "WARP-Cli暂时不支持目前VPS的CPU架构, 请使用CPU架构为amd64的VPS" && exit 1
    
    checktun

    checkwgcf
    if [[ $wgcfv4 =~ on|plus ]] ||[[ $wgcfv6 =~ on|plus ]]; then
        stopwgcf
        checkv4v6
        startwgcf
    else
        checkv4v6
    fi

    if [[ -z $v4 ]]; then
        red "WARP-Cli暂时不支持纯IPv6的VPS，退出安装！"
        exit 1
    fi
    
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget net-tools bc htop iputils screen python3
        rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3
        [[ -z $(type -P gpg 2>/dev/null) ]] && ${PACKAGE_INSTALL[int]} gnupg
        [[ -z $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && ${PACKAGE_INSTALL[int]} apt-transport-https
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    warp-cli --accept-tos register >/dev/null 2>&1
    if [[ $warpcli == 1 ]]; then
        yellow "正在启动 WARP-Cli 全局模式"
        warp-cli --accept-tos add-excluded-route 0.0.0.0/0 >/dev/null 2>&1
        warp-cli --accept-tos add-excluded-route ::0/0 >/dev/null 2>&1
        warp-cli --accept-tos set-mode warp >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        sleep 5
        ip -4 rule add from 172.16.0.2 lookup 51820
        ip -4 route add default dev CloudflareWARP table 51820
        ip -4 rule add table main suppress_prefixlength 0
        IPv4=$(curl -s4m8 https://ip.gs/json --interface CloudflareWARP)
        retry_time=0
        until [[ -n $IPv4 ]]; do
            retry_time=$((${retry_time} + 1))
            red "启动 WARP-Cli 全局模式失败，正在尝试重启，重试次数：$retry_time"
            warp-cli --accept-tos disconnect >/dev/null 2>&1
            warp-cli --accept-tos disable-always-on >/dev/null 2>&1
            ip -4 rule delete from 172.16.0.2 lookup 51820
            ip -4 rule delete table main suppress_prefixlength 0
            sleep 2
            warp-cli --accept-tos connect >/dev/null 2>&1
            warp-cli --accept-tos enable-always-on >/dev/null 2>&1
            sleep 5
            ip -4 rule add from 172.16.0.2 lookup 51820
            ip -4 route add default dev CloudflareWARP table 51820
            ip -4 rule add table main suppress_prefixlength 0
            if [[ $retry_time == 6 ]]; then
                warp-cli --accept-tos disconnect >/dev/null 2>&1
                warp-cli --accept-tos disable-always-on >/dev/null 2>&1
                ip -4 rule delete from 172.16.0.2 lookup 51820
                ip -4 rule delete table main suppress_prefixlength 0
                red "由于WARP-Cli全局模式启动重试次数过多 ,已自动卸载WARP-Cli全局模式"
                green "建议如下："
                yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
                yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
                yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
                exit 1
            fi
        done
        green "WARP-Cli全局模式已安装成功！"
        echo ""
        showIP
    fi

    if [[ $warpcli == 2 ]]; then
        read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
        [[ -z $WARPCliPort ]] && WARPCliPort=$(shuf -i 1000-65535 -n 1)
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
            until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; do
                if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
                    yellow "你设置的端口目前已被占用，请重新输入端口"
                    read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
                fi
            done
        fi
        yellow "正在启动Warp-Cli代理模式"
        warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
        warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        sleep 2
        if [[ ! $(ss -nltp) =~ 'warp-svc' ]]; then
            red "由于WARP-Cli代理模式安装失败 ,已自动卸载WARP-Cli代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        else
            green "WARP-Cli代理模式已启动成功!"
            echo ""
            showIP
        fi
    fi
}

warpcli_changeport() {
    if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
    fi
    
    read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
    [[ -z $WARPCliPort ]] && WARPCliPort=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
            fi
        done
    fi
    warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1
    
    yellow "正在启动Warp-Cli代理模式"
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    
    if [[ ! $(ss -nltp) =~ 'warp-svc' ]]; then
        red "WARP-Cli代理模式启动失败！"
        uninstallCli
    else
        green "WARP-Cli代理模式已启动成功并成功修改代理端口！"
        echo ""
        showIP
    fi
}

switchcli(){
    if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        green "WARP-Cli客户端关闭成功! "
        exit 1
    elif [[ $(warp-cli --accept-tos status) =~ Disconnected ]]; then
        yellow "正在启动Warp-Cli"
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        green "WARP-Cli客户端启动成功! "
        exit 1
    fi
}

uninstallcli(){
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos disable-always-on >/dev/null 2>&1
    warp-cli --accept-tos delete >/dev/null 2>&1
    ${PACKAGE_UNINSTALL[int]} cloudflare-warp
    systemctl disable --now warp-svc >/dev/null 2>&1
    green "WARP-Cli客户端已彻底卸载成功!"
}

showIP(){
    if [[ $(warp-cli --accept-tos settings 2>/dev/null | grep "Mode" | awk -F ": " '{print $2}') == "Warp" ]]; then
        INTERFACE='--interface CloudflareWARP'
    fi
    Browser_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
    v4=$(curl -s4m8 https://ip.gs -k $INTERFACE) || v4=$(curl -s4m8 https://ip.gs -k)
    v6=$(curl -s6m8 https://ip.gs -k)
    c4=$(curl -s4m8 https://ip.gs/country -k $INTERFACE) || c4=$(curl -s4m8 https://ip.gs/country -k)
    c6=$(curl -s6m8 https://ip.gs/country -k)
    d4="${RED}未设置${PLAIN}"
    d6="${RED}未设置${PLAIN}"
    w4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k $INTERFACE | grep warp | cut -d= -f2) || w4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    w6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ -n $INTERFACE ]]; then
        n4=$(curl --user-agent "${Browser_UA}" $INTERFACE -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/$81215567" 2>&1) || n4=$(curl -4 --user-agent "${Browser_UA}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    else
        n4=$(curl -4 --user-agent "${Browser_UA}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    fi
    n6=$(curl -6 --user-agent "${Browser_UA}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    
    s5p=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
    w5p=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")
    if [[ -n $s5p ]]; then
        s5s=$(curl -sx socks5h://localhost:$s5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        s5i=$(curl -sx socks5h://localhost:$s5p https://ip.gs -k --connect-timeout 8)
        s5c=$(curl -sx socks5h://localhost:$s5p https://ip.gs/country -k --connect-timeout 8)
        s5n=$(curl -sx socks5h://localhost:$s5p -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    fi
    if [[ -n $w5p ]]; then
        w5d="${RED}未设置${PLAIN}"
        w5s=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        w5i=$(curl -sx socks5h://localhost:$w5p https://ip.gs -k --connect-timeout 8)
        w5c=$(curl -sx socks5h://localhost:$w5p https://ip.gs/country -k --connect-timeout 8)
        w5n=$(curl -sx socks5h://localhost:$w5p -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    fi

    if [[ $w4 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d4=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            t4="${GREEN} $QUOTA ${PLAIN}"
            w4="${GREEN}WARP+${PLAIN}"
        else
            t4="${RED}无限制${PLAIN}"
            w4="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $w4 == "on" ]]; then
        t4="${RED}无限制${PLAIN}"
        w4="${YELLOW}WARP 免费账户${PLAIN}"
    else
        t4="${RED}无限制${PLAIN}"
        w4="${RED}未启用WARP${PLAIN}"
    fi
    if [[ $w6 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d6=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            t6="${GREEN} $QUOTA ${PLAIN}"
            w6="${GREEN}WARP+${PLAIN}"
        else
            t6="${RED}无限制${PLAIN}"
            w6="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $w6 == "on" ]]; then
        t6="${RED}无限制${PLAIN}"
        w6="${YELLOW}WARP 免费账户${PLAIN}"
    else
        t6="${RED}无限制${PLAIN}"
        w6="${RED}未启用WARP${PLAIN}"
    fi
    if [[ $w5s == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            w5d=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            w5t="${GREEN} $QUOTA ${PLAIN}"
            w5="${GREEN}WARP+${PLAIN}"
        else
            w5t="${RED}无限制${PLAIN}"
            w5="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $w5s == "on" ]]; then
        w5t="${RED}无限制${PLAIN}"
        w5="${YELLOW}WARP 免费账户${PLAIN}"
    else
        w5t="${RED}无限制${PLAIN}"
        w5="${RED}未启动${PLAIN}"
    fi
    if [[ $s5s == "plus" ]]; then
        CHECK_TYPE=1
        check_quota
        s5t="${GREEN} $QUOTA ${PLAIN}"
        s5="${GREEN}WARP+${PLAIN}"
    else
        s5t="${RED}无限制${PLAIN}"
        s5="${YELLOW}WARP 免费账户${PLAIN}"
    fi
    
    [[ -z $s5s ]] || [[ $s5s == "off" ]] && s5="${RED}未启动${PLAIN}"
    
    [[ -z $n4 ]] || [[ $n4 == "000" ]] && n4="${RED}无法检测Netflix状态${PLAIN}"
    [[ -z $n6 ]] || [[ $n6 == "000" ]] && n6="${RED}无法检测Netflix状态${PLAIN}"
    [[ $n4 == "200" ]] && n4="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $n6 == "200" ]] && n6="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $s5n == "200" ]] && s5n="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $w5n == "200" ]] && w5n="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $n4 == "403" ]] && n4="${RED}无法解锁 Netflix${PLAIN}"
    [[ $n6 == "403" ]] && n6="${RED}无法解锁 Netflix${PLAIN}"
    [[ $s5n == "403" ]]&& s5n="${RED}无法解锁 Netflix${PLAIN}"
    [[ $w5n == "403" ]]&& w5n="${RED}无法解锁 Netflix${PLAIN}"
    [[ $n4 == "404" ]] && n4="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ $n6 == "404" ]] && n6="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ $s5n == "404" ]] && s5n="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ $w5n == "404" ]] && w5n="${YELLOW}Netflix 自制剧${PLAIN}"
    
    if [[ -n $v4 ]]; then
        echo "----------------------------------------------------------------------------"
        echo -e "IPv4 地址：$v4  地区：$c4  设备名称：$d4"
        echo -e "WARP状态：$w4  剩余流量：$t4  Netfilx解锁状态：$n4"
    fi
    if [[ -n $v6 ]]; then
        echo "----------------------------------------------------------------------------"
        echo -e "IPv6 地址：$v6  地区：$c6  设备名称：$d6"
        echo -e "WARP状态：$w6  剩余流量：$t6  Netfilx解锁状态：$n6"
    fi
    if [[ -n $s5p ]]; then
        echo "----------------------------------------------------------------------------"
        echo -e "WARP-Cli代理端口: 127.0.0.1:$s5p  状态: $s5  剩余流量：$s5t"
        if [[ -n $s5i ]]; then
            echo -e "IP: $s5i  地区: $s5c  Netfilx解锁状态：$s5n"
        fi
    fi
    if [[ -n $w5p ]]; then
        echo "----------------------------------------------------------------------------"
        echo -e "WireProxy代理端口: 127.0.0.1:$w5p  状态: $w5  设备名称：$w5d"
        if [[ -n $w5i ]]; then
            echo -e "IP: $w5i  地区: $w5c  剩余流量：$w5t  Netfilx解锁状态：$w5n"
        fi
    fi
    echo "----------------------------------------------------------------------------"
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
        6) warpcli=1 && installcli ;;
        7) warpcli=2 && installcli ;;
        8) warpcli_changeport ;;
        9) switchcli ;;
        10) uninstallcli ;;
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