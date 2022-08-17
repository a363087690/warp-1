#!/bin/bash

export LANG=en_US.UTF-8

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

failed(){
    red "Wgcf-WARP目前状态异常，正在执行重启操作！"
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    check
}

alive(){
    green "Wgcf-WARP目前运行正常！即将在5分钟后检测wgcf-warp状态"
    sleep 5m
    check
}

check(){
    IPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    IPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $IPv4Status =~ on|plus ]] || [[ $IPv6Status =~ on|plus ]]; then
        alive
    else
        failed
    fi
}

check