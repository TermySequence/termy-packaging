#!/bin/bash

set -ex

if [ ! -f suse/termy-server.spec ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
ghome=~/git/termysequence
ohome=~/git/home:sigalrm/termy-server

vers=$(perl -ne 'print $1 if m/^Version: *(\S+)/' suse/termy-server.spec)
rel=$(perl -ne 'print $1 if m/^Release: *(\d+)/' suse/termy-server.spec)

mkdir -p $phome/build
cd $phome/build

# Server
ln -sf $ghome/termysequence-server-${vers}.tar.xz termysequence-server_${vers}.orig.tar.xz

rm -rf termysequence-${vers}/
tar Jxf termysequence-server_${vers}.orig.tar.xz

cp -Lr $phome/debian.server termysequence-${vers}/debian

(cd termysequence-${vers}/; debuild -d -S -nc -us -uc)

artifacts=($phome/build/termysequence-server_$vers.orig.tar.xz
           $phome/build/termysequence-server_$vers-$rel.debian.tar.xz
           $phome/build/termysequence-server_$vers-$rel.dsc
           $phome/suse/termy-server.spec
           $phome/arch.server/PKGBUILD
           $phome/fedora.server/*.patch)

cd $ohome
for i in *; do
    if [ $i = termy-server.changes ]; then continue; fi
    ofound=0
    for j in "${artifacts[@]}"; do
        if [ $i = $(basename $j) ]; then ofound=1; break; fi
    done
    if [ $ofound = 0 ]; then osc del --force $i; fi
done

cp "${artifacts[@]}" $ohome
osc add *
