Name:    termy-server
Summary: TermySequence terminal multiplexer server
Version: 1.1.0
Release: 1%{?dist}

License: GPL-2.0-only
Group:   System/Console
URL:     https://termysequence.io
Source:  https://termysequence.io/releases/termysequence-server-%{version}.tar.xz

BuildRequires: cmake >= 3.9.0
BuildRequires: gcc-c++
BuildRequires: libcmocka-devel
BuildRequires: libgit2-devel >= 0.26
BuildRequires: libuuid-devel
BuildRequires: systemd-devel >= 235

%{?systemd_requires}
Recommends: libgit2
Recommends: termy-shell-integration-bash

%description
A multiplexing terminal emulator server implementing
the TermySequence protocol.

%package -n termy-shell-integration-bash
Summary: TermySequence iTerm2-compatible bash integration
License: GPL-2.0-only and MIT
Requires: termy-server
BuildArch: noarch
%description -n termy-shell-integration-bash
iTerm2 bash shell integration for TermySequence,
sourced by /etc/profile

%prep
%autosetup -n termysequence-%{version}

%build
# Build type "None" disables Release/Debug CFLAGS and LDFLAGS set by CMake.
# Only the CFLAGS and LDFLAGS specified by rpmbuild will be used.
%cmake \
    -DCMAKE_BUILD_TYPE=None \
    -DBUILD_TESTS=ON \
    -DINSTALL_SHELL_INTEGRATION=ON
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
%{_userunitdir}/termy-server.*
%{_mandir}/man1/termy*.1*

%files -n termy-shell-integration-bash
%license COPYING.txt
%license vendor/iTerm2/COPYING.bash-preexec
%{_sysconfdir}/profile.d/termy*

%changelog
