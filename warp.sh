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
wg1="sed -i '/0\.0\.0\.0\/0/d' wgcf-profile.conf"
wg2="sed -i '/\:\:\/0/d' wgcf-profile.conf"
# Wgcf Endpoint
wg3="sed -i 's/engage.cloudflareclient.com/162.159.193.10/g' wgcf-profile.conf"
wg4="sed -i 's/engage.cloudflareclient.com/[2606:4700:d0::a29f:c001]/g' wgcf-profile.conf"
# Wgcf DNS Servers
wg5="sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' wgcf-profile.conf"
wg6="sed -i 's/1.1.1.1/2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,8.8.8.8,8.8.4.4/g' wgcf-profile.conf"
# Wgcf 允许外部IP地址
wg7='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf'
wg8='sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf'
wg9='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf && sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" wgcf-profile.conf'

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

checkMTU(){
    yellow "正在设置MTU最佳值, 请稍等..."
    v66=$(curl -s6m8 https://ip.gs -k)
    v44=$(curl -s4m8 https://ip.gs -k)
    MTUy=1500
    MTUc=10
    if [[ -n ${v66} && -z ${v44} ]]; then
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
    green "MTU 最佳值=$MTU 已设置完毕"
}

checkTun(){
    if [[ ! $TUN =~ "in bad state"|"处于错误状态"|"ist in schlechter Verfassung" ]]; then
        if [[ $VIRT == lxc ]]; then
            if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
                red "检测到未开启TUN模块, 请到VPS厂商的控制面板处开启"
                exit 1
            else
                return 0
            fi
        elif [[ $VIRT == "openvz" ]]; then
            wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/tun.sh && bash tun.sh
        else
            red "检测到未开启TUN模块, 请到VPS厂商的控制面板处开启"
            exit 1
        fi
    fi
}

checkStatus(){
    IPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    IPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $IPv4Status =~ on|plus ]] || [[ $IPv6Status =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        v66=$(curl -s6m8 https://ip.gs -k)
        v44=$(curl -s4m8 https://ip.gs -k)
        wg-quick up wgcf >/dev/null 2>&1
    else
        v66=$(curl -s6m8 https://ip.gs -k)
        v44=$(curl -s4m8 https://ip.gs -k)
    fi

    if [[ -n $v44 && -z $v66 ]]; then
        if [[ $wgcfmode == 4 ]]; then
            yellow "检测到为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4)"
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg2
            wgcf4=$wg3
        fi
        if [[ $wgcfmode == 6 ]]; then
            yellow "检测到为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg1
            wgcf3=$wg3
        fi
        if [[ $wgcfmode == 5 ]]; then
            yellow "检测到为纯IPv4的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg7
            wgcf3=$wg3
        fi
        if [[ $warpcli == 1 ]]; then
            yellow "检测到为纯IPv4的VPS，正在安装WARP-Cli代理模式"
        fi
    fi
    if [[ -z $v44 && -n $v66 ]]; then
        if [[ $wgcfmode == 4 ]]; then
            yellow "检测到为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg6
            wgcf2=$wg2
            wgcf3=$wg4
        fi
        if [[ $wgcfmode == 6 ]]; then
            yellow "检测到为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv6)"
            wgcf1=$wg6
            wgcf2=$wg8
            wgcf3=$wg1
            wgcf4=$wg4
        fi
        if [[ $wgcfmode == 5 ]]; then
            yellow "检测到为纯IPv6的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg6
            wgcf2=$wg2
            wgcf3=$wg4
        fi
        if [[ $warpcli == 1 ]]; then
            yellow "检测到为纯IPv6的VPS，纯IPv6的VPS暂时不支持WARP-Cli代理模式"
            exit 1
        fi
    fi
    if [[ -n $v44 && -n $v66 ]]; then
        if [[ $wgcfmode == 4 ]]; then
            yellow "检测到为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg5
            wgcf2=$wg9
            wgcf3=$wg2
        fi
        if [[ $wgcfmode == 6 ]]; then
            yellow "检测到为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg9
            wgcf3=$wg1
        fi
        if [[ $wgcfmode == 5 ]]; then
            yellow "检测到为原生双栈的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg5
            wgcf2=$wg9
        fi
        if [[ $warpcli == 1 ]]; then
            yellow "检测到为原生双栈的VPS，正在安装WARP-Cli代理模式"
        fi
    fi
    sleep 2
}

installWgcf(){
    checkStatus
    checkTun

    [[ $SYSTEM == "CentOS" ]] && [[ ${OSID} -lt 7 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 7及以上版本的系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ${OSID} -lt 10 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Debian 10及以上版本的系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && [[ ${OSID} -lt 29 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Fedora 29及以上版本的系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ${OSID} -lt 16 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Ubuntu 16.04及以上版本的系统" && exit 1

    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables htop screen iputils
        if [[ $OSID == 9 ]] && [[ -z $(type -P resolvconf) ]]; then
            wget -N https://raw.githubusercontent.com/taffychan/warp/main/resolvconf -O /usr/sbin/resolvconf
            chmod +x /usr/sbin/resolvconf
        fi
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables htop screen iputils
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl lsb-release htop screen inetutils-ping
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release htop screen inetutils-ping
        if [[ $OSID =~ 16 ]]; then
            add-apt-repository ppa:wireguard/wireguard
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    
    if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]] || [[ $VIRT =~ lxc|openvz ]]; then
        wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/wireguard-go-$(archAffix) -O /usr/bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi
    
    wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/wgcf_2.2.15_linux_$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf

    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
        wgcfFile=1
    fi
    if [[ -f /root/wgcf-account.toml ]]; then
        wgcfFile=1
    fi
    
    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP注册账号, 如提示429 Too Many Requests错误请耐心等待重试注册即可"
        yes | wgcf register
        sleep 5
    done
    chmod +x wgcf-account.toml
    
    if [[ ! $wgcfFile == 1 ]]; then
        yellow "使用WARP免费版账户请按回车跳过 \n如需使用WARP+账户, 请复制WARP+的许可证密钥(26个字符)后回车"
        read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
        if [[ -n $warpkey ]]; then
            sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml
            read -rp "请输入自定义设备名，如未输入则使用随机设备名: " warpname
            green "注册WARP+账户中, 如下方显示: 400 Bad Request, 则使用WARP免费版账户"
            if [[ -n $warpname ]]; then
                wgcf update --name $(echo $warpname | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi
        fi
    fi
    
    wgcf generate
    chmod +x wgcf-profile.conf

    echo $wgcf1 | sh
    echo $wgcf2 | sh
    echo $wgcf3 | sh
    echo $wgcf4 | sh
    
    checkMTU
    sed -i "s/MTU.*/MTU = $MTU/g" wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1
    
    WgcfV4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfV6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfV4Status =~ "on"|"plus" ]] || [[ $WgcfV6Status =~ "on"|"plus" ]]; do
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstallWgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多, 已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速! 如已使用第三方源及内核加速, 请务必更新到最新版, 或重置为系统官方源! "
            yellow "2. 部分VPS系统过于精简, 相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/ 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1
    
    green "Wgcf-WARP 已安装成功"
    echo ""
    showIP
}

switchWgcf(){
    WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    
    if [[ $WgcfWARP4Status =~ on|plus ]] || [[ $WgcfWARP6Status =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1
        green "Wgcf-WARP关闭成功!"
        exit 1
    fi
    
    if [[ $WgcfWARP4Status == off ]] || [[ $WgcfWARP6Status == off ]]; then
        wg-quick up wgcf >/dev/null 2>&1
        systemctl enable wg-quick@wgcf >/dev/null 2>&1
        green "Wgcf-WARP启动成功!"
        exit 1
    fi
}

uninstallWgcf(){
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

installCli(){
    [[ $SYSTEM == "CentOS" ]] && [[ ! ${OSID} =~ 8 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 8系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ! ${OSID} =~ 9|10|11 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Debian 9-11系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && yellow "当前系统版本：${CMD} \nWARP-Cli暂时不支持Fedora系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ! ${OSID} =~ 16|18|20|22 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Ubuntu 16.04/18.04/20.04/22.04系统" && exit 1
    
    [[ ! $(archAffix) == "amd64" ]] && red "WARP-Cli暂时不支持目前VPS的CPU架构, 请使用CPU架构为amd64的VPS" && exit 1
    
    checkStatus
    checkTun
    
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget net-tools htop iputils screen
        rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release htop inetutils-ping screen
        [[ -z $(type -P gpg 2>/dev/null) ]] && ${PACKAGE_INSTALL[int]} gnupg
        [[ -z $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && ${PACKAGE_INSTALL[int]} apt-transport-https
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release htop inetutils-ping screen
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    warp-cli --accept-tos register >/dev/null 2>&1
    yellow "使用WARP免费版账户请按回车跳过 \n如需使用WARP+账户, 请复制WARP+的许可证密钥(26个字符)后回车"
    read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
    if [[ -n $warpkey ]]; then
        warp-cli --accept-tos set-license "$warpkey" >/dev/null 2>&1 && sleep 1
        if [[ $(warp-cli --accept-tos account) =~ Limited ]]; then
            green "WARP+账户启用成功"
        else
            red "WARP+账户启用失败, 即将使用WARP免费版账户"
        fi
    fi
    warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
    
    read -rp "请输入WARP-Cli使用的代理端口 (默认40000): " WARPCliPort
    [[ -z $WARPCliPort ]] && WARPCliPort=40000
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WARP-Cli使用的代理端口 (默认40000): " WARPCliPort
            fi
        done
    fi
    warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1
    
    yellow "正在启动Warp-Cli代理模式"
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    WARPCliPort=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
    WARPCliStatus=$(curl -sx socks5h://localhost:$WARPCliPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    sleep 5
    retry_time=0
    until [[ $WARPCliStatus =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        WARPCliStatus=$(curl -sx socks5h://localhost:$WARPCliPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        sleep 5
        if [[ $retry_time == 6 ]]; then
            uninstallCli
            echo ""
            red "由于WARP-Cli代理模式启动重试次数过多 ,已自动卸载WARP-Cli代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done

    socks5IP=$(curl -sx socks5h://localhost:$WARPCliPort ip.gs -k --connect-timeout 8)
    green "WARP-Cli代理模式已启动成功!"
    echo ""
    showIP
}

warpcli_changeport() {
    if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
    fi
    
    read -rp "请输入WARP-Cli使用的代理端口 (默认40000): " WARPCliPort
    [[ -z $WARPCliPort ]] && WARPCliPort=40000
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WARP-Cli使用的代理端口 (默认40000): " WARPCliPort
            fi
        done
    fi
    warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1
    
    yellow "正在启动Warp-Cli代理模式"
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    WARPCliPort=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
    WARPCliStatus=$(curl -sx socks5h://localhost:$WARPCliPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    sleep 5
    retry_time=0
    until [[ $WARPCliStatus =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        WARPCliStatus=$(curl -sx socks5h://localhost:$WARPCliPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        sleep 5
        if [[ $retry_time == 6 ]]; then
            uninstallCli
            echo ""
            red "由于WARP-Cli代理模式启动重试次数过多 ,已自动卸载WARP-Cli代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    socks5IP=$(curl -sx socks5h://localhost:$WARPCliPort ip.gs -k --connect-timeout 8)
    green "WARP-Cli代理模式已启动成功并成功修改代理端口！"
    echo ""
    showIP
}

switchCli(){
    if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        green "WARP-Cli代理模式关闭成功! "
        exit 1
    fi
    if [[ $(warp-cli --accept-tos status) =~ Disconnected ]]; then
        yellow "正在启动Warp-Cli代理模式"
        warp-cli --accept-tos connect >/dev/null 2>&1
        until [[ $(warp-cli --accept-tos status) =~ Connected ]]; do
            red "启动Warp-Cli代理模式失败, 正在尝试重启"
            warp-cli --accept-tos disconnect >/dev/null 2>&1
            warp-cli --accept-tos connect >/dev/null 2>&1
            sleep 5
        done
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        WARPCliPort=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
        green "WARP-Cli代理模式启动成功! "
        exit 1
    fi
}

uninstallCli(){
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos disable-always-on >/dev/null 2>&1
    warp-cli --accept-tos delete >/dev/null 2>&1
    ${PACKAGE_UNINSTALL[int]} cloudflare-warp
    systemctl disable --now warp-svc >/dev/null 2>&1
    green "WARP-Cli代理模式已彻底卸载成功!"
}

installWireProxy(){
    if [[ $c4 == "Hong Kong" || $c6 == "Hong Kong" ]]; then
        red "检测到地区为 Hong Kong 的VPS!"
        yellow "由于 CloudFlare 对 Hong Kong 屏蔽了 Wgcf, 因此无法使用 WireProxy-WARP 代理模式。请使用其他地区的VPS"
        exit 1
    fi
    
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget htop iputils screen
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget htop inetutils-ping screen
    fi
    
    wget -N https://raw.githubusercontent.com/taffychan/warp/main/wireproxy-$(archAffix) -O /usr/local/bin/wireproxy
    chmod +x /usr/local/bin/wireproxy
    
    wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/wgcf_2.2.15_linux_$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf
    
    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
        wgcfFile=1
    fi
    if [[ -f /root/wgcf-account.toml ]]; then
        wgcfFile=1
    fi
    
    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP注册账号, 如提示429 Too Many Requests错误请耐心等待重试注册即可"
        yes | wgcf register
        sleep 5
    done
    chmod +x wgcf-account.toml
    
    if [[ ! $wgcfFile == 1 ]]; then
        yellow "使用WARP免费版账户请按回车跳过 \n如需使用WARP+账户, 请复制WARP+的许可证密钥(26个字符)后回车"
        read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
        if [[ -n $warpkey ]]; then
            sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml
            read -rp "请输入自定义设备名，如未输入则使用随机设备名: " warpname
            green "注册WARP+账户中, 如下方显示: 400 Bad Request, 则使用WARP免费版账户"
            if [[ -n $warpname ]]; then
                wgcf update --name $(echo $warpname | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi
        fi
    fi
    
    wgcf generate
    chmod +x wgcf-profile.conf
    
    IPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    IPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    
    if [[ $IPv4Status =~ "on"|"plus" ]] || [[ $IPv6Status =~ "on"|"plus" ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        checkMTU
        wg-quick up wgcf >/dev/null 2>&1
    else
        checkMTU
    fi
    
    read -rp "请输入WireProxy-WARP使用的代理端口 (默认40000): " WireProxyPort
    [[ -z $WireProxyPort ]] && WireProxyPort=40000
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WireProxyPort") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WireProxyPort") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WireProxyPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WireProxy-WARP使用的代理端口 (默认40000): " WireProxyPort
            fi
        done
    fi
    
    WgcfPrivateKey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
    WgcfPublicKey=$(grep PublicKey wgcf-profile.conf | sed "s/PublicKey = //g")
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    
    [[ $VPSIP == 0 ]] && WireproxyEndpoint="[2606:4700:d0::a29f:c001]:2408"
    [[ $VPSIP == 1 || $VPSIP == 2 ]] && WireproxyEndpoint="162.159.193.10:2408"
    
    cat <<EOF > /etc/wireguard/proxy.conf
[Interface]
Address = 172.16.0.2/32
MTU = $MTU
PrivateKey = $WgcfPrivateKey
DNS = 1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844
[Peer]
PublicKey = $WgcfPublicKey
Endpoint = $WireproxyEndpoint
[Socks5]
BindAddress = 127.0.0.1:$WireProxyPort
EOF
    
    cat <<'TEXT' > /etc/systemd/system/wireproxy-warp.service
[Unit]
Description=CloudFlare WARP Socks5 proxy mode based for WireProxy, script by owo.misaka.rest
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/root
ExecStart=/usr/local/bin/wireproxy -c /etc/wireguard/proxy.conf
Restart=always
TEXT
    
    rm -f wgcf-profile.conf
    mv wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 WireProxy-WARP 代理模式"
    systemctl start wireproxy-warp
    WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    retry_time=0
    until [[ $WireProxyStatus =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $retry_time == 6 ]]; then
            uninstallWireProxy
            echo ""
            red "由于WireProxy-WARP 代理模式启动重试次数过多 ,已自动卸载WireProxy-WARP 代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/ 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用WireProxy-WARP 代理模式"
            yellow "4. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
        sleep 8
    done
    sleep 5
    systemctl enable wireproxy-warp >/dev/null 2>&1
    socks5IP=$(curl -sx socks5h://localhost:$WireProxyPort https://ip.gs -k --connect-timeout 8)
    green "WireProxy-WARP代理模式已启动成功!"
    echo ""
    showIP
}

wireproxy_changeport(){
    systemctl stop wireproxy-warp
    read -rp "请输入WireProxy-WARP使用的代理端口 (默认40000): " WireProxyPort
    [[ -z $WireProxyPort ]] && WireProxyPort=40000
    if [[ -n $(netstat -ntlp | grep "$WireProxyPort") ]]; then
        until [[ -z $(netstat -ntlp | grep "$WireProxyPort") ]]; do
            if [[ -n $(netstat -ntlp | grep "$WireProxyPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WireProxy-WARP使用的代理端口 (默认40000): " WireProxyPort
            fi
        done
    fi
    CurrentPort=$(grep BindAddress /etc/wireguard/proxy.conf)
    sed -i "s/$CurrentPort/BindAddress = 127.0.0.1:$WireProxyPort/g" /etc/wireguard/proxy.conf
    yellow "正在启动 WireProxy-WARP 代理模式"
    systemctl start wireproxy-warp
    WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    retry_time=0
    until [[ $WireProxyStatus =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $retry_time == 6 ]]; then
            uninstallWireProxy
            echo ""
            red "由于WireProxy-WARP 代理模式启动重试次数过多 ,已自动卸载WireProxy-WARP 代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/ 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用WireProxy-WARP 代理模式"
            yellow "4. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
        sleep 8
    done
    systemctl enable wireproxy-warp
    green "WireProxy-WARP代理模式已启动成功并已修改端口！"
    echo ""
    showIP
}

switchWireproxy(){
    w5p=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")
    w5s=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    if [[ $w5s =~ "on"|"plus" ]]; then
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp
        green "WireProxy-WARP代理模式关闭成功!"
    fi
    if [[ $w5s =~ "off" ]] || [[ -z $w5s ]]; then
        systemctl start wireproxy-warp
        systemctl enable wireproxy-warp
        green "WireProxy-WARP代理模式已启动成功!"
    fi
}

uninstallWireProxy(){
    systemctl stop wireproxy-warp
    systemctl disable wireproxy-warp
    rm -f /etc/systemd/system/wireproxy-warp.service /usr/local/bin/wireproxy /etc/wireguard/proxy.conf
    if [[ ! -f /etc/wireguard/wgcf.conf ]]; then
        rm -f /usr/local/bin/wgcf /etc/wireguard/wgcf-account.toml
    fi
    green "WireProxy-WARP代理模式已彻底卸载成功!"
}

warpup(){
    yellow "获取CloudFlare WARP账号信息方法: "
    green "电脑: 下载并安装CloudFlare WARP→设置→偏好设置→复制设备ID到脚本中"
    green "手机: 下载并安装1.1.1.1 APP→菜单→高级→诊断→复制设备ID到脚本中"
    echo ""
    yellow "请按照下面指示, 输入您的CloudFlare WARP账号信息:"
    read -rp "请输入您的WARP设备ID (36位字符): " license
    read -rp "请输入你期望刷到的流量 (单位: GB): " flowdata
    echo ""
    echo -e "已设置你期望刷到的WARP+流量为: $flowdata GB"
    yellow "正在准备刷WARP+流量, 请稍等30秒-1分钟..."
    for ((i = 0; i < ${flowdata}; i++)); do
        [[ $i == 0 ]] && sleep_try=30 && sleep_min=20 && sleep_max=600
        install_id=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22) && \
        curl -X POST -m 10 -sA "okhttp/3.12.1" -H 'content-type: application/json' -H 'Host: api.cloudflareclient.com' \
        --data "{\"key\": \"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 43)=\",\"install_id\": \"$install_id\",\"fcm_token\": \"APA91b$install_id$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 134)\",\"referrer\": \"$license\",\"warp_enabled\": false,\"tos\": \"$(date -u +%FT%T.$(tr -dc '0-9' </dev/urandom | head -c 3)Z)\",\"type\": \"Android\",\"locale\": \"en_US\"}" \
        --url "https://api.cloudflareclient.com/v0a$(shuf -i 100-999 -n 1)/reg" | grep -qE "referral_count\":1" && status=0 || status=1
        [[ $sleep_try > $sleep_max ]] && sleep_try=300
        [[ $sleep_try == $sleep_min ]] && sleep_try=$((sleep_try+1))
        [[ $status == 0 ]] && sleep_try=$((sleep_try-1)) && sleep $sleep_try && rit[i]=$i && echo -n $i-o- && continue
        [[ $status == 1 ]] && sleep_try=$((sleep_try+2)) && sleep $sleep_try && bad[i]=$i && echo -n $i-x- && continue
    done
    echo ""
    echo -e "本次运行共成功获取WARP+流量 ${GREEN} ${#rit[*]} ${PLAIN} GB"
}

warpsw1_freeplus(){
    warpPublicKey=$(grep PublicKey wgcf-profile.conf | sed "s/PublicKey = //g")
    warpPrivateKey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
    warpIPv4Address=$(grep "Address = 172" wgcf-profile.conf | sed "s/Address = //g")
    warpIPv6Address=$(grep "Address = fd01" wgcf-profile.conf | sed "s/Address = //g")
    sed -i "s#PublicKey.*#PublicKey = $warpPublicKey#g" /etc/wireguard/wgcf.conf;
    sed -i "s#PrivateKey.*#PrivateKey = $warpPrivateKey#g" /etc/wireguard/wgcf.conf;
    sed -i "s#Address.*32#Address = $warpIPv4Address#g" /etc/wireguard/wgcf.conf;
    sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
    rm -f wgcf-profile.conf
}

warpsw3_freeplus(){
    warpIPv4Address=$(grep "Address = 172" wgcf-profile.conf | sed "s/Address = //g")
    warpPublicKey=$(grep PublicKey wgcf-profile.conf | sed "s/PublicKey = //g")
    warpPrivateKey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
    sed -i "s#PublicKey.*#PublicKey = $warpPublicKey#g" /etc/wireguard/wgcf.conf;
    sed -i "s#PrivateKey.*#PrivateKey = $warpPrivateKey#g" /etc/wireguard/proxy.conf;
    sed -i "s#Address.*32#Address = $warpIPv4Address/32#g" /etc/wireguard/proxy.conf;
    rm -f wgcf-profile.conf
}

warpsw_teams(){
    read -rp "请复制粘贴WARP Teams账户配置文件链接: " teamconfigurl
    [[ -z $teamconfigurl ]] && red "未输入配置文件链接，无法升级！" && exit 1
    teamsconfig=$(curl -sSL "$teamconfigurl" | sed "s/\"/\&quot;/g")
    wpteampublickey=$(expr "$teamsconfig" : '.*public_key&quot;:&quot;\([^&]*\).*')
    wpteamprivatekey=$(expr "$teamsconfig" : '.*private_key&quot;>\([^<]*\).*')
    wpteamv6address=$(expr "$teamsconfig" : '.*v6&quot;:&quot;\([^[&]*\).*')
    wpteamv4address=$(expr "$teamsconfig" : '.*v4&quot;:&quot;\(172[^&]*\).*')
    green "你的WARP Teams配置文件信息如下:"
    yellow "PublicKey: $wpteampublickey"
    yellow "PrivateKey: $wpteamprivatekey"
    yellow "IPv4地址: $wpteamv4address"
    yellow "IPv6地址: $wpteamv6address"
    echo ""
    read -rp "确认配置信息信息正确请输入y, 其他按键退出升级过程: " wpteamconfirm
}

warpsw1(){
    yellow "请选择切换的账户类型"
    green "1. WARP 免费账户"
    green "2. WARP+"
    green "3. WARP Teams"
    read -rp "请选择账户类型 [1-3]: " accountInput
    if [[ $accountInput == 1 ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        cd /etc/wireguard
        rm -f wgcf-account.toml
        until [[ -a wgcf-account.toml ]]; do
            yes | wgcf register
            sleep 5
        done
        chmod +x wgcf-account.toml
        wgcf generate
        chmod +x wgcf-profile.conf
        warpsw1_freeplus
        wg-quick up wgcf >/dev/null 2>&1
        yellow "正在检查WARP 免费账户连通性，请稍等..." && sleep 5
        WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        if [[ $WgcfWARP4Status == "on" ]] || [[ $WgcfWARP6Status == "on" ]]; then
            green "Wgcf-WARP 账户类型切换为 WARP 免费账户 成功！"
        else
            red "切换 Wgcf-WARP 账户类型失败，请卸载后重新切换账户！"
        fi
    fi
    if [[ $accountInput == 2 ]]; then
        cd /etc/wireguard
        if [[ ! -f wgcf-account.toml ]]; then
            until [[ -a wgcf-account.toml ]]; do
                yes | wgcf register
                sleep 5
            done
        fi
        chmod +x wgcf-account.toml
        read -rp "输入WARP账户许可证密钥 (26个字符): " WPPlusKey
        if [[ -n $WPPlusKey ]]; then
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " WPPlusName
            green "注册WARP+账户中, 如下方显示:400 Bad Request, 则使用WARP免费版账户"
            if [[ -n $WPPlusName ]]; then
                wgcf update --name $(echo $WPPlusName | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi
            wgcf generate
            chmod +x wgcf-profile.conf
            wg-quick down wgcf >/dev/null 2>&1
            warpsw1_freeplus
            wg-quick up wgcf >/dev/null 2>&1
            yellow "正在检查WARP+账户连通性，请稍等..." && sleep 5
            WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            if [[ $WgcfWARP4Status == "plus" ]] || [[ $WgcfWARP6Status == "plus" ]]; then
                green "Wgcf-WARP 账户类型切换为 WARP+ 成功！"
            else
                red "切换 Wgcf-WARP 账户类型失败，请卸载后重新切换账户！"
            fi
        else
            red "未输入WARP账户许可证密钥, 无法升级！"
        fi
    fi
    if [[ $accountInput == 3 ]]; then
        warpsw_teams
        if [[ $wpteamconfirm =~ "y"|"Y" ]]; then
            wg-quick down wgcf >/dev/null 2>&1
            sed -i "s#PublicKey.*#PublicKey = $wpteampublickey#g" /etc/wireguard/wgcf.conf;
            sed -i "s#PrivateKey.*#PrivateKey = $wpteamprivatekey#g" /etc/wireguard/wgcf.conf;
            sed -i "s#Address.*32#Address = $wpteamv4address/32#g" /etc/wireguard/wgcf.conf;
            sed -i "s#Address.*128#Address = $wpteamv6address/128#g" /etc/wireguard/wgcf.conf;
            wg-quick up wgcf >/dev/null 2>&1
            yellow "正在检查WARP Teams账户连通性, 请稍等..."
            WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            retry_time=1
            until [[ $WgcfWARP4Status =~ on|plus ]] || [[ $WgcfWARP6Status =~ on|plus ]]; do
                red "无法联通WARP Teams账户, 正在尝试重启, 重试次数：$retry_time"
                retry_time=$((${retry_time} + 1))
                if [[ $retry_time == 4 ]]; then
                    wg-quick down wgcf >/dev/null 2>&1
                    cd /etc/wireguard
                    wgcf generate
                    chmod +x wgcf-profile.conf
                    warpsw1_freeplus
                    wg-quick up wgcf >/dev/null 2>&1
                    red "WARP Teams配置有误, 已自动降级至WARP 免费账户 / WARP+"
                fi
            done
            green "Wgcf-WARP 账户类型切换为 WARP Teams 成功！"
        else
            red "已退出WARP Teams账号升级过程!"
        fi
    fi
}

warpsw2(){
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos register >/dev/null 2>&1
    read -rp "输入WARP账户许可证密钥 (26个字符): " WPPlusKey
    if [[ -n $WPPlusKey ]]; then
        warp-cli --accept-tos set-license "$WPPlusKey" >/dev/null 2>&1 && sleep 1
    fi
    warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
    warp-cli --accept-tos set-proxy-port "$s5p" >/dev/null 2>&1
    warp-cli --accept-tos connect >/dev/null 2>&1
    if [[ $(warp-cli --accept-tos account) =~ Limited ]]; then
        green "WARP-Cli 账户类型切换为 WARP+ 成功！"
    else
        red "WARP+账户启用失败, 已自动降级至WARP免费版账户"
    fi
}

warpsw3(){
    yellow "请选择切换的账户类型"
    green "1. WARP 免费账户"
    green "2. WARP+"
    green "3. WARP Teams"
    read -rp "请选择账户类型 [1-3]: " accountInput
    if [[ $accountInput == 1 ]]; then
        systemctl stop wireproxy-warp
        cd /etc/wireguard
        rm -f wgcf-account.toml
        until [[ -a wgcf-account.toml ]]; do
            yes | wgcf register
            sleep 5
        done
        chmod +x wgcf-account.toml
        wgcf generate
        chmod +x wgcf-profile.conf
        warpsw3_freeplus
        systemctl start wireproxy-warp
        yellow "正在检查WARP 免费账户连通性，请稍等..." && sleep 5
        WireProxyStatus=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $WireProxyStatus == "on" ]]; then
            green "WireProxy-WARP代理模式 账户类型切换为 WARP 免费账户 成功！"
        else
            red "切换 WireProxy-WARP 代理模式账户类型失败，请卸载后重新切换账户！"
        fi
    fi
    if [[ $accountInput == 2 ]]; then
        cd /etc/wireguard
        if [[ ! -f wgcf-account.toml ]]; then
            until [[ -a wgcf-account.toml ]]; do
                yes | wgcf register
                sleep 5
            done
        fi
        chmod +x wgcf-account.toml
        read -rp "输入WARP账户许可证密钥 (26个字符): " WPPlusKey
        if [[ -n $WPPlusKey ]]; then
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " WPPlusName
            green "注册WARP+账户中, 如下方显示: 400 Bad Request, 则使用WARP免费版账户"
            if [[ -n $WPPlusName ]]; then
                wgcf update --name $(echo $WPPlusName | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi
            wgcf generate
            chmod +x wgcf-profile.conf 
            systemctl stop wireproxy-warp
            warpsw3_freeplus
            systemctl start wireproxy-warp
            yellow "正在检查WARP+账户连通性，请稍等..." && sleep 5
            WireProxyStatus=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            if [[ $WireProxyStatus == "plus" ]]; then
                green "WireProxy-WARP代理模式 账户类型切换为 WARP+ 成功！"
            else
                red "切换 WireProxy-WARP 代理模式账户类型失败，请卸载后重新切换账户！"
            fi
        else
            red "未输入WARP账户许可证密钥, 无法升级！"
        fi
    fi
    if [[ $accountInput == 3 ]]; then
        warpsw_teams
        if [[ $wpteamconfirm =~ "y"|"Y" ]]; then
            systemctl stop wireproxy-warp
            sed -i "s#PublicKey.*#PublicKey = $wpteampublickey#g" /etc/wireguard/proxy.conf;
            sed -i "s#PrivateKey.*#PrivateKey = $wpteamprivatekey#g" /etc/wireguard/proxy.conf;
            sed -i "s#Address.*32#Address = $wpteamv4address/32#g" /etc/wireguard/proxy.conf;
            systemctl start wireproxy-warp
            yellow "正在检查WARP Teams账户连通性, 请稍等..."
            WireProxyStatus=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            retry_time=1
            until [[ $WireProxyStatus == "plus" ]]; do
                red "无法联通WARP Teams账户, 正在尝试重启, 重试次数：$retry_time"
                retry_time=$((${retry_time} + 1))
                if [[ $retry_time == 4 ]]; then
                    systemctl stop wireproxy-warp
                    cd /etc/wireguard
                    wgcf generate
                    chmod +x wgcf-profile.conf
                    warpsw3_freeplus
                    systemctl start wireproxy-warp
                    red "WARP Teams配置有误, 已自动降级至WARP 免费账户 / WARP+"
                fi
            done
            green "WireProxy-WARP代理模式 账户类型切换为 WARP Teams 成功！"
        else
            red "已退出WARP Teams账号升级过程!"
        fi
    fi
}

warpsw(){
    yellow "请选择需要切换WARP账户的WARP客户端:"
    echo -e " ${GREEN}1.${PLAIN} Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} WARP-Cli 代理模式 ${RED}(目前仅支持升级WARP+账户)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} WireProxy-WARP 代理模式"
    read -rp "请选择客户端 [1-3]: " clientInput
    case "$clientInput" in
        1 ) warpsw1 ;;
        2 ) warpsw2 ;;
        3 ) warpsw3 ;;
        * ) exit 1 ;;
    esac
}

warpnf(){
    yellow "请选择需要刷NetFilx IP的WARP客户端:"
    green "1. Wgcf-WARP IPv4模式"
    green "2. Wgcf-WARP IPv6模式"
    green "3. WARP-Cli 代理模式"
    green "4. WireProxy-WARP 代理模式"
    read -rp "请选择客户端 [1-4]: " clientInput
    case "$clientInput" in
        1 ) wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/netflix4.sh && bash netflix4.sh ;;
        2 ) wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/netflix6.sh && bash netflix6.sh ;;
        3 ) wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/netflixcli.sh && bash netflixcli.sh ;;
        4 ) wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/netflixwire.sh && bash netflixwire.sh ;;
    esac
}

showIP(){
    v4=$(curl -s4m8 https://ip.gs -k)
    v6=$(curl -s6m8 https://ip.gs -k)
    c4=$(curl -s4m8 https://ip.gs/country -k)
    c6=$(curl -s6m8 https://ip.gs/country -k)
    w4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    w6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    n4=$(curl -4 --user-agent "${Browser_UA}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
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
        w5s=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        w5i=$(curl -sx socks5h://localhost:$w5p https://ip.gs -k --connect-timeout 8)
        w5c=$(curl -sx socks5h://localhost:$w5p https://ip.gs/country -k --connect-timeout 8)
        w5n=$(curl -sx socks5h://localhost:$w5p -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    fi
    
    [[ -z $s5s ]] || [[ $s5s == "off" ]] && s5="${RED}未启动${PLAIN}"
    [[ -z $w5s ]] || [[ $w5s == "off" ]] && w5="${RED}未启动${PLAIN}"
    [[ $s5s == "on" ]] && s5="${YELLOW}WARP 免费账户${PLAIN}"
    [[ $w5s == "on" ]] && w5="${YELLOW}WARP 免费账户${PLAIN}"
    [[ $s5s == "plus" ]] && s5="${GREEN}WARP+ / Teams${PLAIN}"
    [[ $w5s == "plus" ]] && w5="${GREEN}WARP+ / Teams${PLAIN}"
    [[ $w4 == "off" ]] && w4="${RED}未启用WARP${PLAIN}"
    [[ $w6 == "off" ]] && w6="${RED}未启用WARP${PLAIN}"
    [[ $w4 == "on" ]] && w4="${YELLOW}WARP 免费账户${PLAIN}"
    [[ $w6 == "on" ]] && w6="${YELLOW}WARP 免费账户${PLAIN}"
    [[ $w4 == "plus" ]] && w4="${GREEN}WARP+ / Teams${PLAIN}"
    [[ $w6 == "plus" ]] && w6="${GREEN}WARP+ / Teams${PLAIN}"
    
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
        echo "-------------------------------------------------------------"
        echo -e "IPv4 地址：$v4  地区：$c4"
        echo -e "WARP状态：$w4  Netfilx解锁状态：$n4"
    fi
    if [[ -n $v6 ]]; then
        echo "-------------------------------------------------------------"
        echo -e "IPv6 地址：$v6  地区：$c6"
        echo -e "WARP状态：$w6  Netfilx解锁状态：$n6"
    fi
    if [[ -n $s5p ]]; then
        echo "-------------------------------------------------------------"
        echo -e "WARP-Cli代理端口: 127.0.0.1:$s5p  WARP-Cli状态: $s5"
        if [[ -n $s5i ]]; then
            echo -e "IP: $s5i  地区: $s5c  Netfilx解锁状态：$s5n"
        fi
    fi
    if [[ -n $w5p ]]; then
        echo "-------------------------------------------------------------"
        echo -e "WireProxy代理端口: 127.0.0.1:$w5p  WireProxy状态: $w5"
        if [[ -n $w5i ]]; then
            echo -e "IP: $w5i  地区: $w5c  Netfilx解锁状态：$w5n"
        fi
    fi
    echo "-------------------------------------------------------------"
}

menu(){
    clear
    echo "#############################################################"
    echo -e "#                    ${RED} WARP  一键安装脚本${PLAIN}                    #"
    echo -e "# ${GREEN}作者${PLAIN}: taffychan                                           #"
    echo -e "# ${GREEN}GitHub${PLAIN}: https://github.com/taffychan                      #"
    echo "#############################################################"
    echo -e ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Wgcf-WARP 全局单栈模式 ${YELLOW}(WARP IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 Wgcf-WARP 全局单栈模式 ${YELLOW}(WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 Wgcf-WARP 全局双栈模式"
    echo -e " ${GREEN}4.${PLAIN} 开启或关闭 Wgcf-WARP"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}6.${PLAIN} 安装 WARP-Cli 代理模式 ${RED}(仅支持纯IPv4或原生双栈、CPU架构为AMD64的VPS)${PLAIN}"
    echo -e " ${GREEN}7.${PLAIN} 修改 WARP-Cli 代理模式连接端口"
    echo -e " ${GREEN}8.${PLAIN} 开启或关闭 WARP-Cli 代理模式"
    echo -e " ${GREEN}9.${PLAIN} ${RED}卸载 WARP-Cli 代理模式${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}10.${PLAIN} 安装 Wireproxy-WARP 代理模式"
    echo -e " ${GREEN}11.${PLAIN} 修改 Wireproxy-WARP 代理模式连接端口"
    echo -e " ${GREEN}12.${PLAIN} 开启或关闭 Wireproxy-WARP 代理模式"
    echo -e " ${GREEN}13.${PLAIN} ${RED}卸载 Wireproxy-WARP 代理模式${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}14.${PLAIN} 获取 WARP+ 账户流量"
    echo -e " ${GREEN}15.${PLAIN} 切换 WARP 账户类型"
    echo -e " ${GREEN}16.${PLAIN} 获取解锁 Netflix 的 WARP IP"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo -e ""
    showIP
    echo -e ""
    read -rp "请输入选项 [0-16]：" menuChoice
    case $menuChoice in
        1) wgcfmode=4 && installWgcf ;;
        2) wgcfmode=6 && installWgcf ;;
        3) wgcfmode=5 && installWgcf ;;
        4) switchWgcf ;;
        5) uninstallWgcf ;;
        6) warpcli=1 && installCli ;;
        7) warpcli_changeport ;;
        8) switchCli ;;
        9) uninstallCli ;;
        10) installWireProxy ;;
        11) wireproxy_changeport ;;
        12) switchWireProxy ;;
        13) uninstallWireProxy ;;
        14 ) warpup ;;
        15 ) warpsw ;;
        16 ) warpnf ;;
        *) red "请输入正确的选项！" && exit 1 ;;
    esac
}

menu
