#!/bin/bash

rm -f ${GITHUB_WORKSPACE}/files/wireproxy/wireproxy-amd64 ${GITHUB_WORKSPACE}/files/wireproxy/wireproxy-arm64 ${GITHUB_WORKSPACE}/files/wireproxy/wireproxy-s390x ${GITHUB_WORKSPACE}/files/logs/wireproxy-fetchlog.txt

actions_date=$(date)
repo_last_ver=$(curl -Ls "https://api.github.com/repos/octeep/wireproxy/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

wget -N https://github.com/octeep/wireproxy/releases/download/$repo_last_ver/wireproxy_linux_amd64.tar.gz
tar -zxvf wireproxy_linux_amd64.tar.gz
rm -f wireproxy_linux_amd64.tar.gz
mv -f wireproxy ${GITHUB_WORKSPACE}/files/wireproxy/wireproxy-amd64

wget -N https://github.com/octeep/wireproxy/releases/download/$repo_last_ver/wireproxy_linux_arm64.tar.gz
tar -zxvf wireproxy_linux_arm64.tar.gz
rm -f wireproxy_linux_arm64.tar.gz
mv -f wireproxy ${GITHUB_WORKSPACE}/files/wireproxy/wireproxy-arm64

wget -N https://github.com/octeep/wireproxy/releases/download/$repo_last_ver/wireproxy_linux_s390x.tar.gz
tar -zxvf wireproxy_linux_s390x.tar.gz
rm -f wireproxy_linux_s390x.tar.gz
mv -f wireproxy ${GITHUB_WORKSPACE}/files/wireproxy/wireproxy-s390x

cat <<EOF > ${GITHUB_WORKSPACE}/files/logs/wireproxy-fetchlog.txt
# wireproxy fetch log generated by GitHub Actions

Last Version: $repo_last_ver
Fetch Date: $actions_date
EOF

rm -f wireproxy.sh