#!/bin/bash

set -e

if [ ! -d debian.server ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

release=bionic

phome=$(pwd)
ghome=~/git/termysequence
ident=$(git config user.email)

vers=$(perl -ne 'm/\((.*)-.*\)/; print $1; exit' debian.server/changelog)
rel=$(perl -ne 'm/\(.*-(.*)\)/; print $1; exit' debian.server/changelog)

mkdir -p ~/deb
cd ~/deb

ln -sf $ghome/termysequence-server-${vers}.tar.xz .
ln -sf $ghome/termysequence-server-${vers}.tar.xz termysequence-server_${vers}.orig.tar.xz

rm -rf termysequence-${vers}/
tar Jxf termysequence-server-${vers}.tar.xz

cp -rL $phome/debian.server termysequence-${vers}/debian

cd termysequence-${vers}/
sed -ie "1 s/unstable/$release/" debian/changelog
debuild -d -S -sa -k${ident}

read -p 'build? ' build
if [ "$build" = 'y' ]; then
    debuild -d -us -uc
fi

read -p 'upload? ' upload
if [ "$upload" = 'y' ]; then
    cd ~/deb
    dput -f ppa:sigalrm/termysequence termysequence-server_${vers}-${rel}_source.changes
fi
