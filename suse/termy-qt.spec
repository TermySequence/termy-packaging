Name:    termy-qt
Summary: TermySequence terminal multiplexer client
Version: 1.1.4
Release: 1%{?dist}

# This is a limitation of the bundled v8 library
ExclusiveArch: %{ix86} x86_64

# Main source distribution is GPL-2.0-only
# vendor/termy-icon-theme is LGPL-3.0-only
# vendor/termy-emoji is CC-BY-4.0
# vendor/v8-linux is BSD-3-Clause
License: GPL-2.0-only and LGPL-3.0-only and CC-BY-4.0 and BSD-3-Clause
Group:   System/X11/Terminals
URL:     https://termysequence.io
Source:  termysequence-qt_%{version}.orig.tar.xz

BuildRequires: appstream-glib
BuildRequires: cmake >= 3.9.0
BuildRequires: desktop-file-utils
BuildRequires: fuse-devel >= 2.9.7
BuildRequires: gcc-c++
BuildRequires: libatomic1
BuildRequires: libicu-devel >= 60.2
BuildRequires: libqt5-qtbase-devel libqt5-qtsvg-devel libqt5-linguist-devel
BuildRequires: libuuid-devel
BuildRequires: ninja >= 1.8.2
BuildRequires: python2-Jinja2 >= 2.10
BuildRequires: sqlite-devel
BuildRequires: systemd-devel >= 235
BuildRequires: zlib-devel
BuildRequires: /usr/bin/python

Requires: termy-server
Requires: fuse
Requires: /usr/bin/notify-send

Provides: bundled(v8) = 6.9.427.27

%description
A Qt-based multiplexing terminal emulator client
implementing the TermySequence protocol.

%prep
%autosetup -n termysequence-%{version}

%build
%ifarch x86_64
%global v8arch x64
%endif
%ifarch %{ix86}
%global v8arch x86
%endif

# Build type "None" disables Release/Debug CFLAGS and LDFLAGS set by CMake.
# Only the CFLAGS and LDFLAGS specified by rpmbuild will be used.
%cmake -DCMAKE_BUILD_TYPE=None -DUSE_FUSE2=1 -DUSE_FUSE3=0 -DV8_ARCH=%{v8arch}
# Disable output sync so that V8 sub-make output is not buffered
%define _make_output_sync %{nil}
%make_build
%define _make_output_sync -O

%install
cd build && %make_install install_emoji install_icons

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/qtermy.desktop
appstream-util validate-relax --nonet %{buildroot}%{_datadir}/metainfo/qtermy.appdata.xml

%files
%license COPYING.txt
%license vendor/termy-icon-theme/COPYING
%license vendor/termy-icon-theme/COPYING.Adwaita
%license vendor/termy-icon-theme/COPYING.Oxygen
%license vendor/termy-emoji/LICENSE-GRAPHICS
%license vendor/v8-linux/v8/LICENSE.v8
%{_bindir}/qtermy
%{_bindir}/qtermy-pipe
%{_datadir}/qtermy
%{_datadir}/applications/qtermy.desktop
%{_datadir}/metainfo/qtermy.appdata.xml
%{_datadir}/pixmaps/qtermy.svg
%{_mandir}/man1/qtermy*.1*

%changelog
