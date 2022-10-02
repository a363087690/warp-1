#!/bin/bash

rm -f ${GITHUB_WORKSPACE}/files/warp-go/warp-go-amd64 ${GITHUB_WORKSPACE}/files/warp-go/warp-go-arm64 ${GITHUB_WORKSPACE}/files/warp-go/warp-go-s390x ${GITHUB_WORKSPACE}/files/logs/warpgo-fetchlog.txt

actions_date=$(date)
repo_last_ver=$(curl -Ls "https://gitlab.com/api/v4/projects/ProjectWARP%2Fwarp-go/releases" | grep -oP '"tag_name":"v\K[^\"]+' | head -n 1)

wget -N https://gitlab.com/ProjectWARP/warp-go/-/releases/v"$repo_last_ver"/downloads/warp-go_"$repo_last_ver"_linux_amd64.tar.gz
tar -zxvf warp-go_"$repo_last_ver"_linux_amd64.tar.gz
rm -f warp-go_"$repo_last_ver"_linux_amd64.tar.gz LICENCE README.md README.zh_CN.md
mv -f warp-go ${GITHUB_WORKSPACE}/files/warp-go/warp-go-amd64

wget -N https://gitlab.com/ProjectWARP/warp-go/-/releases/v"$repo_last_ver"/downloads/warp-go_"$repo_last_ver"_linux_arm64.tar.gz
tar -zxvf warp-go_"$repo_last_ver"_linux_arm64.tar.gz
rm -f warp-go_"$repo_last_ver"_linux_arm64.tar.gz LICENCE README.md README.zh_CN.md
mv -f warp-go ${GITHUB_WORKSPACE}/files/warp-go/warp-go-arm64

wget -N https://gitlab.com/ProjectWARP/warp-go/-/releases/v"$repo_last_ver"/downloads/warp-go_"$repo_last_ver"_linux_s390x.tar.gz
tar -zxvf warp-go_"$repo_last_ver"_linux_s390x.tar.gz
rm -f warp-go_"$repo_last_ver"_linux_s390x.tar.gz LICENCE README.md README.zh_CN.md
mv -f warp-go ${GITHUB_WORKSPACE}/files/warp-go/warp-go-s390x

cat <<EOF > ${GITHUB_WORKSPACE}/files/logs/warpgo-fetchlog.txt
# warp-go fetch log generated by GitHub Actions

Last Version: $repo_last_ver
Fetch Date: $actions_date
EOF

rm -f warp-go.sh