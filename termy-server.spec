Name:    termy-server
Summary: TermySequence terminal multiplexer server
Version: 1.0.3
Release: 1%{?dist}

License: GPLv2
URL:     https://termysequence.io
Source:  https://termysequence.io/releases/termysequence-%{version}.tar.xz

BuildRequires: cmake >= 3.9.0
BuildRequires: gcc-c++
BuildRequires: libcmocka-devel
BuildRequires: libgit2-devel >= 0.26
BuildRequires: libuuid-devel
BuildRequires: systemd-devel >= 235
BuildRequires: utf8cpp-devel >= 2.3.4

%{?systemd_requires}
Recommends: libgit2
Recommends: termy-shell-integration-bash

%description
A multiplexing terminal emulator server implementing
the TermySequence protocol.

%package -n termy-shell-integration-bash
Summary: iTerm2-compatible bash integration for TermySequence
License: GPLv2 and MIT
Requires: termy-server
BuildArch: noarch
%description -n termy-shell-integration-bash
iTerm2 bash shell integration for TermySequence,
sourced by /etc/profile

%prep
%autosetup -n termysequence-%{version}
# Avoid the bundled copy of UTF8-CPP
rm -rf vendor/utf8cpp

%build
%cmake \
    -DCMAKE_BUILD_TYPE=None \
    -DBUILD_TESTS=ON \
    -DBUILD_QTGUI=OFF \
    -DINSTALL_SHELL_INTEGRATION=ON \
    .
%make_build

%install
%make_install

%check
ctest -V

%post
%systemd_user_post termy-server.socket

%preun
%systemd_user_preun termy-server.service termy-server.socket

%files
%license COPYING.txt
%{_bindir}/termy*
%{_userunitdir}/termy-server.*
%{_mandir}/man1/termy*.1*

%files -n termy-shell-integration-bash
%license COPYING.txt
%license vendor/iTerm2/COPYING.bash-preexec
%{_sysconfdir}/profile.d/termy*

%changelog
* Tue Jun 05 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.3-1
- Update to 1.0.3
- Set CMAKE_BUILD_TYPE to None

* Sat Jun 02 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.2-2
- Set CMAKE_BUILD_TYPE to Release

* Mon May 28 2018 Eamon Walsh <ewalsh@termysequence.com> - 1.0.2-1
- Initial package for Fedora
