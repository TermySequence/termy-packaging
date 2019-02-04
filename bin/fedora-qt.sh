#!/bin/bash

set -e

if [ ! -f fedora.qt/termy-qt.spec ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
vers=$(awk '/^Version:/ {print $2}' fedora.qt/termy-qt.spec)
rel=$(awk '/^Release:/ {print $2}' fedora.qt/termy-qt.spec | awk -F% '{print $1}')

mkdir -p ~/rpmbuild/SPECS
ln -sf $phome/fedora.qt/termy-qt.spec ~/rpmbuild/SPECS/
for i in $phome/fedora.qt/*.patch; do
    ln -sf "$i" ~/rpmbuild/SOURCES/
done

mkdir -p ~/rpmbuild/SOURCES
cd ~/rpmbuild/SOURCES
ln -sf $ghome/termysequence-qt-${vers}.tar.xz .

cd ~/rpmbuild/SPECS
rpmbuild -bs termy-qt.spec

read -p 'build? ' build
if [ "$build" = 'y' ]; then
    rpmbuild -ba termy-qt.spec
fi

read -p 'upload? ' upload
if [ "$upload" = 'y' ]; then
    dist=$(rpm -q --queryformat '%{release}' systemd | awk -F. '{print $NF}')
    cd ~/rpmbuild/SRPMS
    copr build --nowait termysequence termy-qt-${vers}-${rel}.${dist}.src.rpm
fi
