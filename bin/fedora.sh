#!/bin/bash

set -e

if [ ! -f termy-server.spec ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
dist=$(rpm -q --queryformat '%{release}' systemd | awk -F. '{print $NF}')

vers=$(awk '/^Version:/ {print $2}' termy-qt.spec)
icons_vers=$(awk '/^%global icons_version / {print $3}' termy-qt.spec)
emoji_vers=$(awk '/^%global emoji_version / {print $3}' termy-qt.spec)

server_rel=$(awk '/^Release:/ {print $2}' termy-server.spec | awk -F% '{print $1}')
qt_rel=$(awk '/^Release:/ {print $2}' termy-qt.spec | awk -F% '{print $1}')

mkdir -p ~/rpmbuild/SPECS
ln -sf $phome/termy-server.spec ~/rpmbuild/SPECS
ln -sf $phome/termy-qt.spec ~/rpmbuild/SPECS

mkdir -p ~/rpmbuild/SOURCES
cd ~/rpmbuild/SOURCES
wget https://termysequence.io/releases/termysequence-${vers}.tar.xz
wget https://termysequence.io/releases/termy-icon-theme-${icons_vers}.tar.xz
wget https://termysequence.io/releases/termy-emoji-${emoji_vers}.tar.xz

cd ~/rpmbuild/SPECS
rpmbuild -bs termy-server.spec
rpmbuild -bs termy-qt.spec

read -p 'upload? ' upload
if [ "$upload" = 'y' ]; then
    cd ~/rpmbuild/SRPMS
    copr build --nowait termysequence termy-server-${vers}-${server_rel}.${dist}.src.rpm
    copr build --nowait termysequence termy-qt-${vers}-${qt_rel}.${dist}.src.rpm
fi
