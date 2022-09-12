#!/bin/bash

rm -f ${GITHUB_WORKSPACE}/netfilx/verify/nf_linux_amd64 ${GITHUB_WORKSPACE}/netfilx/verify/nf_linux_arm64

actions_date=$(date)
repo_last_ver=$(curl -Ls "https://api.github.com/repos/sjlleo/netflix-verify/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

wget -N https://github.com/sjlleo/netflix-verify/releases/download/$repo_last_ver/nf_linux_amd64 -O ${GITHUB_WORKSPACE}/netfilx/verify/nf_linux_amd64

wget -N https://github.com/sjlleo/netflix-verify/releases/download/$repo_last_ver/nf_linux_arm64 -O ${GITHUB_WORKSPACE}/netfilx/verify/nf_linux_arm64

cat <<EOF > ${GITHUB_WORKSPACE}/netfilx/verify/logs/nfverify-fetchlog.txt
# Netfilx verify fetch log generated by GitHub Actions

Last Version: $repo_last_ver
Fetch Date: $actions_date
EOF

rm -f nfverify.sh