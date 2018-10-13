#!/bin/bash

set -e

if [ ! "$1" -o ! "$2" ]; then
    echo "Usage: $0 <server|qt|doc> <version>" 1>&2
    exit 1
fi

if [ $1 = doc ]; then
    name=termy-doc-html
    cd ~/git/termy-doc
else
    name=termysequence-$1
    cd ~/git/termysequence
fi

version=$2
ident=$(git config user.email)

echo "VERSION is $version"
echo "● Signing..."
if [ ! -f $name-$version.sig ]; then
    gpg -s -b --default-key "$ident" --output $name-$version.sig \
        $name-$version.tar.xz
fi
if [ ! -f $name-$version.sha256 ]; then
    sha256sum $name-$version.tar.xz >$name-$version.sha256
fi

echo "● Editing..."
pushd ~/git/termy-website
perl -pi -e "s/$name-[\\d\\.]+\\.tar/$name-$version.tar/g" releases/index.rst
perl -pi -e "s/$name-[\\d\\.]+\\.sig/$name-$version.sig/g" releases/index.rst
perl -pi -e "s/$name-[\\d\\.]+\\.sha256/$name-$version.sha256/g" releases/index.rst

echo "● Building..."
make html
popd

read -p 'upload? ' upload
if [ "$upload" != 'y' ]; then exit 0; fi

echo "● Uploading..."
scp $name-$version.{tar.xz,sig,sha256} \
    ~/git/termy-website/_build/html/releases/index.html \
    termysequence.com:io/releases/

if [ $1 = doc ]; then
    read -p 'upload docs? ' dupload
    if [ "$dupload" != 'y' ]; then exit 0; fi
    cd ~/git/termy-doc/_build/html
    scp -r * termysequence.com:io/doc/
fi
