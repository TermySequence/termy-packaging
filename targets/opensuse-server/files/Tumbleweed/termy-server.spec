Name:    termy-server
Summary: TermySequence terminal multiplexer server
Version: 1.1.4
Release: 3%{?dist}

License: GPL-2.0-only
Group:   System/Console
URL:     https://termysequence.io
Source:  termysequence-server_%{version}.orig.tar.xz

# Patches here (do not remove this comment)
Patch1: setup-fix-session-check.patch

BuildRequires: cmake >= 3.9.0
BuildRequires: gcc-c++
BuildRequires: libcmocka-devel
BuildRequires: libgit2-devel >= 0.26
BuildRequires: libuuid-devel
BuildRequires: systemd-devel >= 235

%{?systemd_requires}
Recommends: libgit2
Obsoletes: termy-shell-integration-bash

%description
A multiplexing terminal emulator server implementing
the TermySequence protocol.

%prep
%autosetup -p1 -n termysequence-%{version}

%build
# Build type "None" disables Release/Debug CFLAGS and LDFLAGS set by CMake.
# Only the CFLAGS and LDFLAGS specified by rpmbuild will be used.
%cmake -DCMAKE_BUILD_TYPE=None -DBUILD_TESTS=ON
%make_build

%install
cd build && %make_install

%check
cd build && ctest -V

%post
%systemd_user_post termy-server.socket

%preun
%systemd_user_preun termy-server.service termy-server.socket

%files
%license COPYING.txt
%{_bindir}/termy*
%{_datadir}/termy-server
%{_userunitdir}/termy-server.*
%{_mandir}/man1/termy*.1*

%changelog
