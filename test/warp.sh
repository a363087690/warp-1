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
        1) wgcfmode=4 && checkStatus ;;
        2) wgcfmode=6 && checkStatus ;;
        3) wgcfmode=5 && checkStatus ;;
        4) switchWgcf ;;
        5) uninstallWgcf ;;
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