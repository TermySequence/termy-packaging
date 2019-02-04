#!/bin/bash

set -e

if [ ! -f fedora.server/termy-server.spec ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
ghome=~/git/termysequence
vers=$(awk '/^Version:/ {print $2}' fedora.server/termy-server.spec)
rel=$(awk '/^Release:/ {print $2}' fedora.server/termy-server.spec | awk -F% '{print $1}')

mkdir -p ~/rpmbuild/SPECS
ln -sf $phome/fedora.server/termy-server.spec ~/rpmbuild/SPECS/
for i in $phome/fedora.server/*.patch; do
    ln -sf "$i" ~/rpmbuild/SOURCES/
done

mkdir -p ~/rpmbuild/SOURCES
cd ~/rpmbuild/SOURCES
ln -sf $ghome/termysequence-server-${vers}.tar.xz .

cd ~/rpmbuild/SPECS
rpmbuild -bs termy-server.spec

read -p 'build? ' build
if [ "$build" = 'y' ]; then
    rpmbuild -ba termy-server.spec
fi

read -p 'upload? ' upload
if [ "$upload" = 'y' ]; then
    dist=$(rpm -q --queryformat '%{release}' systemd | awk -F. '{print $NF}')
    cd ~/rpmbuild/SRPMS
    copr build --nowait termysequence termy-server-${vers}-${rel}.${dist}.src.rpm
fi
