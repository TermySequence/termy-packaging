#!/bin/bash

set -e

if [ ! -f termy-server.spec ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
vers=$(awk '/^Version:/ {print $2}' termy-server.spec)
rel=$(awk '/^Release:/ {print $2}' termy-server.spec | awk -F% '{print $1}')

mkdir -p ~/rpmbuild/SPECS
ln -sf $phome/termy-server.spec ~/rpmbuild/SPECS

mkdir -p ~/rpmbuild/SOURCES
cd ~/rpmbuild/SOURCES
wget https://termysequence.io/releases/termysequence-server-${vers}.tar.xz

cd ~/rpmbuild/SPECS
rpmbuild -bs termy-server.spec

read -p 'upload? ' upload
if [ "$upload" = 'y' ]; then
    dist=$(rpm -q --queryformat '%{release}' systemd | awk -F. '{print $NF}')
    cd ~/rpmbuild/SRPMS
    copr build --nowait termysequence termy-server-${vers}-${rel}.${dist}.src.rpm
fi
