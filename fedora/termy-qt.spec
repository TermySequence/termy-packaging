Name:    termy-qt
Summary: TermySequence terminal multiplexer client
Version: 1.1.1
Release: 1%{?dist}

# This is a limitation of the bundled v8 library
ExclusiveArch: %{ix86} x86_64

# Main source distribution is GPLv2
# vendor/termy-icon-theme is LGPLv3
# vendor/termy-emoji is CC-BY
# vendor/v8-linux is BSD
License: GPLv2 and LGPLv3 and CC-BY and BSD
URL:     https://termysequence.io
Source:  https://termysequence.io/releases/termysequence-qt-%{version}.tar.xz

BuildRequires: cmake >= 3.9.0
BuildRequires: desktop-file-utils
BuildRequires: fuse3-devel
BuildRequires: gcc-c++
BuildRequires: libappstream-glib
BuildRequires: libatomic
BuildRequires: libgit2-devel >= 0.26
BuildRequires: libicu-devel >= 60.2
BuildRequires: libuuid-devel
BuildRequires: ninja-build >= 1.8.2
BuildRequires: qt5-qtbase-devel qt5-qtsvg-devel qt5-linguist
BuildRequires: sqlite-devel
BuildRequires: systemd-devel >= 235
BuildRequires: utf8cpp-devel >= 2.3.4
BuildRequires: zlib-devel
BuildRequires: /usr/bin/python

Requires: termy-server
Requires: fuse3
Requires: /usr/bin/notify-send

Provides: bundled(v8) = 6.8.275.14

%description
A Qt-based multiplexing terminal emulator client
implementing the TermySequence protocol.

%prep
%autosetup -n termysequence-%{version}
# Avoid the bundled copy of UTF8-CPP
rm -rf vendor/utf8cpp

%build
%ifarch x86_64
%global v8arch x64
%endif
%ifarch %{ix86}
%global v8arch x86
%endif

%cmake -DCMAKE_BUILD_TYPE=Release -DV8_ARCH=%{v8arch} .
%make_build

%install
%make_install install_emoji install_icons

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/*.desktop
appstream-util validate-relax --nonet %{buildroot}%{_datadir}/metainfo/*.appdata.xml

%files
%license COPYING.txt
%license vendor/termy-icon-theme/COPYING
%license vendor/termy-icon-theme/COPYING.Adwaita
%license vendor/termy-icon-theme/COPYING.Oxygen
%license vendor/termy-emoji/LICENSE-GRAPHICS
%{_bindir}/qtermy*
%{_datadir}/qtermy
%{_datadir}/applications/*.desktop
%{_datadir}/metainfo/*.appdata.xml
%{_datadir}/pixmaps/qtermy.*
%{_mandir}/man1/qtermy*.1*

%changelog
* Fri Sep 21 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.1.1-1
- Update to 1.1.1
- Set CMAKE_BUILD_TYPE back to Release (#1583798)
- Provide bundled(v8)

* Thu Aug 09 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.1.0-1
- Update to 1.1.0

* Tue Jun 05 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.3-1
- Update to 1.0.3
- Set CMAKE_BUILD_TYPE to None

* Sat Jun 02 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.2-2
- Set CMAKE_BUILD_TYPE to Release

* Mon May 28 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.2-1
- Initial package for Fedora
