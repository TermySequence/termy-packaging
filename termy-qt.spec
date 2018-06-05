Name:    termy-qt
Summary: TermySequence terminal multiplexer client
Version: 1.0.3
Release: 1%{?dist}

# This is a limitation of the v8 dependency
ExclusiveArch: %{ix86} x86_64 %{arm} ppc mipsel mips64el

%global icons_version 1.0.1
%global emoji_version 1.0.0

License: GPLv2 and LGPLv3 and CC-BY
URL:     https://termysequence.io
Source:  https://termysequence.io/releases/termysequence-%{version}.tar.xz
Source1: https://termysequence.io/releases/termy-icon-theme-%{icons_version}.tar.xz
Source2: https://termysequence.io/releases/termy-emoji-%{emoji_version}.tar.xz

BuildRequires: cmake >= 3.9.0
BuildRequires: desktop-file-utils
BuildRequires: fuse3-devel
BuildRequires: gcc-c++
BuildRequires: libappstream-glib
BuildRequires: libgit2-devel >= 0.26
BuildRequires: libuuid-devel
BuildRequires: qt5-qtbase-devel qt5-qtsvg-devel qt5-linguist
BuildRequires: sqlite-devel
BuildRequires: systemd-devel >= 235
BuildRequires: utf8cpp-devel >= 2.3.4
BuildRequires: v8-devel >= 1:6.7.17
BuildRequires: zlib-devel

Requires: termy-server
Requires: fuse3
Requires: /usr/bin/notify-send

%description
A Qt-based multiplexing terminal emulator client
implementing the TermySequence protocol.

%prep
%autosetup -n termysequence-%{version}
%setup -q -D -T -a 1 -n termysequence-%{version}
%setup -q -D -T -a 2 -n termysequence-%{version}
# Avoid the bundled copy of UTF8-CPP
rm -rf vendor/utf8cpp

%build
%cmake -DCMAKE_BUILD_TYPE=None -DBUILD_SERVER=OFF .
%make_build

%install
%make_install
%make_install PREFIX=%{_prefix} -C termy-icon-theme-%{icons_version}
%make_install PREFIX=%{_prefix} -C termy-emoji-%{emoji_version}

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/*.desktop
appstream-util validate-relax --nonet %{buildroot}%{_datadir}/metainfo/*.appdata.xml

%files
%license COPYING.txt
%license termy-icon-theme-%{icons_version}/COPYING
%license termy-icon-theme-%{icons_version}/COPYING.Adwaita
%license termy-icon-theme-%{icons_version}/COPYING.Oxygen
%license termy-emoji-%{emoji_version}/LICENSE-GRAPHICS
%{_bindir}/qtermy*
%{_datadir}/qtermy
%{_datadir}/applications/*.desktop
%{_datadir}/metainfo/*.appdata.xml
%{_datadir}/pixmaps/qtermy.*
%{_mandir}/man1/qtermy*.1*

%changelog
* Tue Jun 05 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.3-1
- Update to 1.0.3
- Set CMAKE_BUILD_TYPE to None

* Sat Jun 02 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.2-2
- Set CMAKE_BUILD_TYPE to Release

* Mon May 28 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.2-1
- Initial package for Fedora
