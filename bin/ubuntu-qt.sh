#!/bin/bash

set -e

if [ ! -d debian.qt ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
ident=$(git config user.email)

vers=$(awk '/^# version:/ {print $3}' debian.qt/control)
rel=$(awk '/^# release:/ {print $3}' debian.qt/control)

mkdir -p ~/deb
cd ~/deb

wget -nc https://termysequence.io/releases/termysequence-qt-${vers}.tar.xz
ln -sf termysequence-qt-${vers}.tar.xz termysequence-qt_${vers}.orig.tar.xz

rm -rf termysequence-${vers}/
tar Jxf termysequence-qt-${vers}.tar.xz

cp -r $phome/debian.qt termysequence-${vers}/debian

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
    dput ppa:sigalrm/termysequence termysequence-qt_${vers}-${rel}_source.changes
fi
