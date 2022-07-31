#!/bin/bash

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

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

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ $EUID -ne 0 ]] && red "注意: 请在root用户下运行脚本" && exit 1

if [[ -z $(type -P screen) ]]; then
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} screen
fi

check_status(){
    yellow "正在检查VPS系统及IP配置环境, 请稍等..."
    if [[ -z $(type -P curl) ]]; then
        yellow "检测curl未安装, 正在安装中..."
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} curl
    fi
    
    IPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    IPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    Browser_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
    
    if [[ $IPv4Status =~ "on"|"plus" ]] || [[ $IPv6Status =~ "on"|"plus" ]]; then
        # 关闭Wgcf-WARP，以防识别有误
        wg-quick down wgcf >/dev/null 2>&1
        v66=$(curl -s6m8 https://ip.gs -k)
        v44=$(curl -s4m8 https://ip.gs -k)
        wg-quick up wgcf >/dev/null 2>&1
    else
        v66=$(curl -s6m8 https://ip.gs -k)
        v44=$(curl -s4m8 https://ip.gs -k)
    fi
    
    [[ $IPv4Status == "off" ]] && w4="${RED}未启用WARP${PLAIN}"
    [[ $IPv6Status == "off" ]] && w6="${RED}未启用WARP${PLAIN}"
    [[ $IPv4Status == "on" ]] && w4="${YELLOW}WARP 免费账户${PLAIN}"
    [[ $IPv6Status == "on" ]] && w6="${YELLOW}WARP 免费账户${PLAIN}"
    [[ $IPv4Status == "plus" ]] && w4="${GREEN}WARP+ / Teams${PLAIN}"
    [[ $IPv6Status == "plus" ]] && w6="${GREEN}WARP+ / Teams${PLAIN}"
    
    v4=$(curl -s4m8 https://ip.gs -k)
    v6=$(curl -s6m8 https://ip.gs -k)
    c4=$(curl -s4m8 https://ip.gs/country -k)
    c6=$(curl -s6m8 https://ip.gs/country -k)
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
}

statustext(){
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
    echo -e ""
}

wgcfnfv4(){
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        v4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        if [[ $v4status =~ "on"|"plus" ]]; then
            cat <<TEXT > /root/netflixv4.sh
#!/bin/bash

export LANG=en_US.UTF-8

check(){
    NetfilxStatus=$(curl -4 --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36 Edg/99.0.1150.39" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    if [[ $NetfilxStatus == "200" ]]; then
        success
    fi
    if [[ $NetfilxStatus =~ "403"|"404" ]]; then
        failed  
    fi
    if [[ -z $NetfilxStatus ]] || [[ $NetfilxStatus == "000" ]]; then
        retry
    fi
}

retry(){
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    check
}

success(){
    WgcfWARPIP=$(curl -s4m8 https://ip.gs -k)
    green "当前Wgcf-WARP的IP：$WgcfWARPIP 已解锁Netfilx"
    yellow "等待1小时后，脚本将会自动重新检查Netfilx解锁状态"
    sleep 1h
    check
}

failed(){
    WgcfWARPIP=$(curl -s4m8 https://ip.gs -k)
    red "当前Wgcf-WARP的IP：$WgcfWARPIP 未解锁Netfilx，脚本将在15秒后重新测试Netfilx解锁情况"
    sleep 15
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    check
}

check
TEXT
            screen -USdm netflixv4 bash /root/netflixv4.sh
            green "已创建一个名为netflixv4的screen会话，可使用screen -r netflixv4查看脚本执行日志"
            exit 1
        fi
    else
        red "未安装Wgcf-WARP，脚本自动退出！"
        exit 1
    fi
}

wgcfnfv6(){
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        v6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        if [[ $v6status =~ "on"|"plus" ]]; then
            cat <<TEXT > /root/netflixv6.sh
#!/bin/bash

export LANG=en_US.UTF-8

check(){
    NetfilxStatus=$(curl -6 --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36 Edg/99.0.1150.39" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    if [[ $NetfilxStatus == "200" ]]; then
        success
    fi
    if [[ $NetfilxStatus =~ "403"|"404" ]]; then
        failed  
    fi
    if [[ -z $NetfilxStatus ]] || [[ $NetfilxStatus == "000" ]]; then
        retry
    fi
}

retry(){
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    check
}

success(){
    WgcfWARPIP=$(curl -s6m8 https://ip.gs -k)
    green "当前Wgcf-WARP的IP：$WgcfWARPIP 已解锁Netfilx"
    yellow "等待1小时后，脚本将会自动重新检查Netfilx解锁状态"
    sleep 1h
    check
}

failed(){
    WgcfWARPIP=$(curl -s6m8 https://ip.gs -k)
    red "当前Wgcf-WARP的IP：$WgcfWARPIP 未解锁Netfilx，脚本将在15秒后重新测试Netfilx解锁情况"
    sleep 15
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    check
}

check
TEXT
            screen -USdm netflixv6 bash /root/netflixv6.sh
            green "已创建一个名为netflixv6的screen会话，可使用screen -r netflixv6查看脚本执行日志"
            exit 1
        fi
    else
        red "未安装Wgcf-WARP，脚本自动退出！"
        exit 1
    fi
}

warpclinf(){
    if [[ -n $(type -P warp-cli) ]]; then
        cat <<TEXT > /root/netflixcli.sh
#!/bin/bash

export LANG=en_US.UTF-8

WARPCliPort=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')

check(){
    NetfilxStatus=$(curl -sx socks5h://localhost:$WARPCliPort -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    if [[ $NetfilxStatus == "200" ]]; then
        success
    fi
    if [[ $NetfilxStatus =~ "403"|"404" ]]; then
        failed  
    fi
    if [[ -z $NetfilxStatus ]] || [[ $NetfilxStatus == "000" ]]; then
        retry
    fi
}

retry(){
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos connect >/dev/null 2>&1
    check
}

success(){
    WARPCliIP=$(curl -sx socks5h://localhost:$WARPCliPort https://ip.gs -k --connect-timeout 8)
    green "当前WireProxy-WARP的IP：$WARPCliIP 已解锁Netfilx"
    yellow "等待1小时后，脚本将会自动重新检查Netfilx解锁状态"
    sleep 1h
    check
}

failed(){
    WARPCliIP=$(curl -sx socks5h://localhost:$WARPCliPort https://ip.gs -k --connect-timeout 8)
    red "当前WireProxy-WARP的IP：$WARPCliIP 未解锁Netfilx，脚本将在15秒后重新测试Netfilx解锁情况"
    sleep 15
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos connect >/dev/null 2>&1
    check
}

check
TEXT
        screen -USdm netflixcli bash /root/netflixcli.sh
        green "已创建一个名为netflixcli的screen会话，可使用screen -r netflixcli查看脚本执行日志"
        exit 1
    else
        red "未安装WARP-Cli 代理模式，脚本自动退出！"
        exit 1
    fi
}

wireproxynf(){
    if [[ -n $(type -P wireproxy) ]]; then
        cat <<TEXT > /root/netflixwire.sh
#!/bin/bash

export LANG=en_US.UTF-8

WireProxyPort=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")

check(){
    NetfilxStatus=$(curl -sx socks5h://localhost:$WireProxyPort -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    if [[ $NetfilxStatus == "200" ]]; then
        success
    fi
    if [[ $NetfilxStatus =~ "403"|"404" ]]; then
        failed  
    fi
    if [[ -z $NetfilxStatus ]] || [[ $NetfilxStatus == "000" ]]; then
        retry
    fi
}

retry(){
    systemctl stop wireproxy-warp
    systemctl start wireproxy-warp
    check
}

success(){
    WireProxyIP=$(curl -sx socks5h://localhost:$WireProxyPort https://ip.gs -k --connect-timeout 8)
    green "当前WireProxy-WARP的IP：$WireProxyIP 已解锁Netfilx"
    yellow "等待1小时后，脚本将会自动重新检查Netfilx解锁状态"
    sleep 1h
    check
}

failed(){
    WireProxyIP=$(curl -sx socks5h://localhost:$WireProxyPort https://ip.gs -k --connect-timeout 8)
    red "当前WireProxy-WARP的IP：$WireProxyIP 未解锁Netfilx，脚本将在15秒后重新测试Netfilx解锁情况"
    sleep 15
    systemctl stop wireproxy-warp
    systemctl start wireproxy-warp
    check
}

check
TEXT
        screen -USdm netflixwire bash /root/netflixwire.sh
        green "已创建一个名为netflixwire的screen会话，可使用screen -r netflixwire查看脚本执行日志"
        exit 1
    else
        red "未安装WireProxy-WARP 代理模式，脚本自动退出！"
        exit 1
    fi
}

menu(){
    echo ""
    yellow "请选择需要刷NetFilx IP的WARP客户端:"
    green "1. Wgcf-WARP IPv4模式"
    green "2. Wgcf-WARP IPv6模式"
    green "3. WARP-Cli 代理模式"
    green "4. WireProxy-WARP 代理模式"
    echo ""
    statustext
    echo ""
    read -rp "请选择客户端 [1-4]: " clientInput
    case "$clientInput" in
        1) wgcfnfv4 ;;
        2) wgcfnfv6 ;;
        3) warpclinf ;;
        4) wireproxynf ;;
        *) red "请输入正确的选项 [1-4] ！" && exit 1 ;;
    esac
}

check_status
menu