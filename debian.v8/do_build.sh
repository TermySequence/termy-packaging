#!/bin/bash

set -ex

v8arch=$1
v8conf="use_sysroot=false use_gold=false linux_use_bundled_binutils=false \
is_component_build=true clang_use_chrome_plugins=false libcpp_is_static=true \
v8_use_external_startup_data=false v8_target_cpu=\"$v8arch\" is_clang=false"

SPLITOPTFLAGS=""
for i in `dpkg-buildflags --get CXXFLAGS | sed 's/ /\n/g'`; do
	SPLITOPTFLAGS+="\"$i\", "
done
export SPLITOPTFLAGS

SPLITLDFLAGS=""
for j in `dpkg-buildflags --get LDFLAGS | sed 's/ /\n/g'`; do
	SPLITLDFLAGS+="\"$j\", "
done
export SPLITLDFLAGS

sed -i "s|\"\$OPTFLAGS\"|$SPLITOPTFLAGS|g" build/config/compiler/BUILD.gn
sed -i "s|\"\$OPTLDFLAGS\"|$SPLITLDFLAGS|g" build/config/compiler/BUILD.gn

rm -rf third_party/binutils/Linux_x64/Release/bin/ld.gold
rm -rf third_party/llvm-build/Release+Asserts
# mkdir -p third_party/llvm-build/Release+Asserts/bin
# pushd third_party/llvm-build/Release+Asserts/bin
# ln -s /usr/bin/clang clang
# ln -s /usr/bin/clang++ clang++
# ln -s /usr/bin/llvm-ar llvm-ar
# popd

mv gn tools
(cd tools/gn/ && ./bootstrap/bootstrap.py -s)
rm -rf buildtools/linux64/gn*
cp -a out/Release/gn buildtools/linux64/gn

rm -rf depot/ninja
ln -s /usr/bin/ninja depot/ninja

export PATH=$PATH:$(pwd)/depot
CHROMIUM_BUILDTOOLS_PATH=./buildtools/ gn gen out.gn/$v8arch.release --args="$v8conf"
mkdir -p out.gn/$v8arch.release/gen/shim_headers/icui18n_shim/third_party/icu/source/i18n/unicode
mkdir -p out.gn/$v8arch.release/gen/shim_headers/icuuc_shim/third_party/icu/source/common/unicode
depot/ninja -vvv -C out.gn/$v8arch.release -j 2
