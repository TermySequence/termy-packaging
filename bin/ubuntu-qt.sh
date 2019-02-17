#!/bin/bash

set -e

if [ ! -d debian.qt ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

releases=(bionic cosmic)

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

for release in "${releases[@]}"; do
    cd termysequence-${vers}/

    sed -e "1 s/unstable/$release/g" $phome/debian.qt/changelog > debian/changelog
    debuild -d -S -sa -k${ident}

    read -p "build $release? " build
    if [ "$build" = 'y' ]; then
        debuild -d -us -uc
    fi

    read -p "upload $release? " upload
    if [ "$upload" = 'y' ]; then
        cd ~/deb
        dput -f ppa:sigalrm/termysequence termysequence-qt_${vers}-${rel}_source.changes
    fi
done
