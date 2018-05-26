#!/bin/bash

set -ex

v8arch=$1
v8lib=$2
somajor=6

buildroot=$(pwd)/debian/tmp
includedir=/usr/include
bindir=/usr/bin
libdir=/usr/lib/$v8lib

pushd out.gn/$v8arch.release
# library first
mkdir -p $buildroot$libdir
cp -a libv8*.so.$somajor $buildroot$libdir
# Next, binaries
mkdir -p $buildroot$bindir
install -p -m0755 d8 $buildroot$bindir
install -p -m0755 mksnapshot $buildroot$bindir
popd

# Now, headers
mkdir -p $buildroot$includedir
install -p include/*.h $buildroot$includedir
cp -a include/libplatform $buildroot$includedir
# Are these still useful?
mkdir -p $buildroot$includedir/v8/extensions/
install -p src/extensions/*.h $buildroot$includedir/v8/extensions/

# Make shared library links
pushd $buildroot$libdir
ln -sf libv8.so.$somajor libv8.so
ln -sf libv8_libplatform.so.$somajor libv8_libplatform.so
ln -sf libv8_libbase.so.$somajor libv8_libbase.so
popd
