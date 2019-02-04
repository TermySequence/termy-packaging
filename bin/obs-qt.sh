#!/bin/bash

set -ex

if [ ! -f suse/termy-qt.spec ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
ghome=~/git/termysequence
ohome=~/git/home:sigalrm/termy-qt

vers=$(perl -ne 'print $1 if m/^Version: *(\S+)/' suse/termy-qt.spec)
rel=$(perl -ne 'print $1 if m/^Release: *(\d+)/' suse/termy-qt.spec)

mkdir -p $phome/build
cd $phome/build

# Qt
ln -sf $ghome/termysequence-qt-${vers}.tar.xz termysequence-qt_${vers}.orig.tar.xz

rm -rf termysequence-${vers}/
tar Jxf termysequence-qt_${vers}.orig.tar.xz

cp -Lr $phome/debian.qt termysequence-${vers}/debian

(cd termysequence-${vers}/; debuild -d -S -nc -us -uc)

artifacts=($phome/build/termysequence-qt_$vers.orig.tar.xz
           $phome/build/termysequence-qt_$vers-$rel.debian.tar.xz
           $phome/build/termysequence-qt_$vers-$rel.dsc
           $phome/suse/termy-qt.spec
           $phome/arch.qt/PKGBUILD
           $phome/fedora.qt/*.patch)

cd $ohome
for i in *; do
    if [ $i = termy-qt.changes ]; then continue; fi
    ofound=0
    for j in "${artifacts[@]}"; do
        if [ $i = $(basename $j) ]; then ofound=1; break; fi
    done
    if [ $ofound = 0 ]; then osc del --force $i; fi
done

cp "${artifacts[@]}" $ohome
osc add *
