#!/bin/bash

set -e

if [ ! -d debian.qt ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
ghome=~/git/termysequence
ident=$(git config user.email)

vers=$(perl -ne 'm/\((.*)-.*\)/; print $1; exit' debian.qt/changelog)
rel=$(perl -ne 'm/\(.*-(.*)\)/; print $1; exit' debian.qt/changelog)

mkdir -p ~/deb
cd ~/deb

ln -sf $ghome/termysequence-qt-${vers}.tar.xz .
ln -sf $ghome/termysequence-qt-${vers}.tar.xz termysequence-qt_${vers}.orig.tar.xz

rm -rf termysequence-${vers}/
tar Jxf termysequence-qt-${vers}.tar.xz

cp -rL $phome/debian.qt termysequence-${vers}/debian

cd termysequence-${vers}/
debuild -d -S -k${ident}

read -p 'build? ' build
if [ "$build" = 'y' ]; then
    debuild -d -us -uc
    exit
fi
