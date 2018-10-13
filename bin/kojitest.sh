#!/bin/bash

set -e

if [ ! -f "$1" ]; then
    echo "Usage: $0 <specfile> <fXX>" 1>&2
    exit 1
fi


mkdir -p /tmp/kojitest
specfile=/tmp/kojitest/$(basename "$1")

#
## FUSE2 test
#
cp "$1" /tmp/kojitest
sed -ie 's/%{version}/rc/' "$specfile"
sed -ie 's/^%cmake/%cmake -DUSE_FUSE3=0 -DUSE_FUSE2=1/' "$specfile"
sed -ie 's/fuse3-devel/fuse-devel/' "$specfile"
srpm=$(rpmbuild -bs "$specfile" | awk '{print $2}')
if [ ! -f "$srpm" ]; then
    echo "Problem generating SRPM, bailing out" 1>&2
    exit 2
fi
koji build --nowait --scratch $2 $srpm

#
## FUSE3 test
#
cp "$1" /tmp/kojitest
sed -ie 's/%{version}/rc/' "$specfile"
srpm=$(rpmbuild -bs "$specfile" | awk '{print $2}')
if [ ! -f "$srpm" ]; then
    echo "Problem generating SRPM, bailing out" 1>&2
    exit 2
fi
koji build --nowait --scratch $2 $srpm
