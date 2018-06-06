#!/bin/bash

set -e

if [ ! -d debian.termy ]; then
    echo 'Run me from the termy-packaging directory' 1>&2
    exit 1
fi

phome=$(pwd)
ident=$(git config user.email)

vers=$(awk '/^# version:/ {print $3}' debian.termy/control)
rel=$(awk '/^# release:/ {print $3}' debian.termy/control)
icons_vers=$(awk '/^# icons_version:/ {print $3}' debian.termy/control)
emoji_vers=$(awk '/^# emoji_version:/ {print $3}' debian.termy/control)

mkdir -p ~/deb
cd ~/deb

wget https://termysequence.io/releases/termysequence-${vers}.tar.xz
ln -sf termysequence-${vers}.tar.xz termysequence_${vers}.orig.tar.xz

wget https://termysequence.io/releases/termy-icon-theme-${icons_vers}.tar.xz
ln -sf termy-icon-theme-${icons_vers}.tar.xz termysequence_${vers}.orig-icons.tar.xz

wget https://termysequence.io/releases/termy-emoji-${emoji_vers}.tar.xz
ln -sf termy-emoji-${emoji_vers}.tar.xz termysequence_${vers}.orig-emoji.tar.xz

rm -rf termysequence-${vers}/
tar Jxf termysequence-${vers}.tar.xz
tar Jxf termy-icon-theme-${icons_vers}.tar.xz -C termysequence-${vers}
tar Jxf termy-emoji-${emoji_vers}.tar.xz -C termysequence-${vers}

(cd termysequence-${vers}; mv termy-icon-theme-${icons_vers} icons)
(cd termysequence-${vers}; mv termy-emoji-${emoji_vers} emoji)
cp -r $phome/debian.termy termysequence-${vers}/debian

cd termysequence-${vers}/
debuild -S -k${ident}

read -p 'upload? ' upload
if [ "$upload" = 'y' ]; then
    cd ~/deb
    dput ppa:sigalrm/termysequence termysequence_${vers}-${rel}_source.changes
fi
