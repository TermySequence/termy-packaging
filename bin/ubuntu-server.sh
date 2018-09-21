#!/bin/bash

set -e

if [ ! -d debian.server ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
ident=$(git config user.email)

vers=$(awk '/^# version:/ {print $3}' debian.server/control)
rel=$(awk '/^# release:/ {print $3}' debian.server/control)

mkdir -p ~/deb
cd ~/deb

wget -nc https://termysequence.io/releases/termysequence-server-${vers}.tar.xz
ln -sf termysequence-server-${vers}.tar.xz termysequence-server_${vers}.orig.tar.xz

rm -rf termysequence-${vers}/
tar Jxf termysequence-server-${vers}.tar.xz

cp -r $phome/debian.server termysequence-${vers}/debian

cd termysequence-${vers}/
debuild -S -k${ident}

read -p 'build? ' build
if [ "$build" = 'y' ]; then
    debuild -us -uc
    exit
fi

read -p 'upload? ' upload
if [ "$upload" = 'y' ]; then
    cd ~/deb
    dput ppa:sigalrm/termysequence termysequence-server_${vers}-${rel}_source.changes
fi
