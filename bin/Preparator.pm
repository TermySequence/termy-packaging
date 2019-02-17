package Preparator;

use warnings;
use strict;
use Date::Format;

#
## Arch
#
sub read_arch_release {
    my ($self, $config) = @_;

    my $specfile = "$$config{phome}/targets/$$config{target}/files/PKGBUILD";
    my ($version, $release);

    open(FH, '<', $specfile) or die;
    while (<FH>) {
        $version = $1 if m/^pkgver=(.*)$/;
        $release = $1 if m/^pkgrel=(\d+)$/;
    }
    close(FH);

    die "No version found for $$config{target}\n" unless defined($version);
    die "$$config{target} is on unexpected $version\n" if $version ne $$config{version};
    die "No release found for $$config{target}\n" unless defined($release);
    return int($release);
}

sub update_arch {
    my ($self, $config) = @_;

    my $updir = "$$config{phome}/upstreams/obs-$$config{product}";
    chdir "$updir/" or die;

    # PKGBUILD
    my (@lines, @sources, @sums, $sum);
    my $actions = 0;
    my $specfile = "$$config{phome}/targets/$$config{target}/files/PKGBUILD";

    push @sources, "\"termysequence-$$config{product}_\$pkgver.orig.tar.xz\"";
    chomp($sum = `cut -d' ' -f1 < $$config{ghome}/termysequence-$$config{product}-$$config{version}.sha256`);
    push @sums, "'$sum'";

    foreach my $patch (@{$$config{series}}) {
        push @sources, "'$patch'";
        chomp($sum = `sha256sum $$config{phome}/patches/$patch | cut -d' ' -f1`);
        push @sums, "'$sum'";
    }

    open(FH, '<', $specfile) or die;
    while (<FH>) {
        chomp;
        if (m/^pkgver=(.*)$/) {
            push @lines, "pkgver=$$config{version}";
            ++$actions;
            next;
        }
        if (m/^pkgrel=(\d+)$/) {
            push @lines, "pkgrel=$$config{release}";
            ++$actions;
            next;
        }
        if (m/^source=/) {
            push @lines, "source=(" . join(' ', @sources) . ")";
            ++$actions;
            next;
        }
        if (m/^sha256sums=/) {
            push @lines, "sha256sums=(" . join(' ', @sums) . ")";
            ++$actions;
            next;
        }
        if (m/^(\s*)# Patches here/) {
            my $indent = $1;
            push @lines, $_;
            foreach my $patch (@{$$config{series}}) {
                push @lines, "${indent}patch -Np1 -i \"\${srcdir}/$patch\"";
            }
            ++$actions;
            next;
        }
        push @lines, $_ unless m/^\s*patch -N/;
    }
    close(FH);
    die unless $actions == 5;

    open(FH, '>', $specfile) or die;
    print FH map("$_\n", @lines);
    close(FH);
    open(FH, '>', 'PKGBUILD') or die;
    print FH map("$_\n", @lines);
    close(FH);

    # Patches
    foreach my $patch (@{$$config{series}}) {
        my $needadd = ! -f $patch;
        system("cp $$config{phome}/patches/$patch .") and die;
        system("osc add $patch") and die if $needadd;
    }

    $$self{did_obs} = 1;
}

#
## Debian
#
sub read_debian_release {
    my ($self, $config) = @_;

    my $specfile = "$$config{phome}/targets/$$config{target}/files/unstable/changelog";
    my ($version, $release);

    open(FH, '<', $specfile) or die;
    my $line = <FH>;
    die unless $line =~ m/\(([\d\.]+)-(\d+)/;
    $version = $1;
    $release = $2;
    close(FH);

    die "No version found for $$config{target}\n" unless defined($version);
    die "$$config{target} is on unexpected $version\n" if $version ne $$config{version};
    die "No release found for $$config{target}\n" unless defined($release);
    return int($release);
}

sub update_debian {
    my ($self, $config) = @_;

    my $filesdir = "$$config{phome}/targets/$$config{target}/files/unstable";
    chdir "$filesdir/" or die;

    # Changelog
    my @lines;

    open(FH, '<', 'changelog') or die;
    @lines = <FH>;
    close(FH);

    while (@lines) {
        # Remove stanzas with same release
        last unless $lines[0] =~ m/^termysequence-$$config{product} \($$config{version}-$$config{release}\D/;
        shift @lines;
        shift @lines while @lines && $lines[0] =~ m/^\s+/;
    }

    open(FH, '>', 'changelog') or die;
    print FH "termysequence-$$config{product} ($$config{version}-$$config{release}) unstable; urgency=medium\n";
    print FH "\n";
    print FH map("  * $_\n", @{$$config{log}});
    print FH "\n";
    my $datespec = time2str("%a, %d %b %Y %H:%M:%S %z", time);
    print FH " -- $$config{fullname} <$$config{email}>  $datespec\n";
    print FH "\n";
    print FH @lines;
    close(FH);

    # Patches
    chdir "patches" or die;
    unlink for glob('*');
    unless (-z "$$config{phome}/targets/$$config{target}/series") {
        symlink "../../../series", "series" or die;
        symlink "../../../../../patches/$_", $_ for @{$$config{series}};
    }

    my $updir = "$$config{phome}/upstreams/obs-$$config{product}";
    chdir "$updir/" or die;

    system("osc delete --force $_") and die for glob("*.dsc *.debian.tar.xz");

    # Debuild
    mkdir "$$config{phome}/build";
    chdir "$$config{phome}/build" or die;

    my $src = "termysequence-$$config{product}-$$config{version}.tar.xz";
    my $obssrc = "termysequence-$$config{product}_$$config{version}.orig.tar.xz";
    symlink "$$config{ghome}/$src", $src;
    symlink "$$config{ghome}/$src", $obssrc;

    my $srcdir = "termysequence-$$config{version}";
    system("rm -rf $srcdir/");
    system("tar Jxf $src");
    system("cp -rL $$config{phome}/targets/$$config{target}/files/unstable $srcdir/debian");

    chdir $srcdir or die;
    system("debuild -d -S -sa -k$$config{email}") and die;
    chdir "$$config{phome}/build" or die;
    system("cp termysequence-$$config{product}_$$config{version}-$$config{release}.dsc $updir/") and die;
    system("cp termysequence-$$config{product}_$$config{version}-$$config{release}.debian.tar.xz $updir/") and die;

    chdir "$updir/" or die;
    system("osc add *.dsc *.debian.tar.xz") and die;

    $$self{did_launchpad} = 1;
    $$self{did_obs} = 1;
}

#
## Fedora
#
sub read_specfile_release {
    my ($self, $config, $dvers) = @_;

    my $specfile = "$$config{phome}/targets/$$config{target}/files/$dvers/termy-$$config{product}.spec";
    my ($version, $release);

    open(FH, '<', $specfile) or die "Failed to open $specfile: $!\n";
    while (<FH>) {
        $version = $1 if m/^Version: (.*)/;
        $release = $1 if m/^Release: (\d+)/
    }
    close(FH);

    die "No version found for $$config{target}\n" unless defined($version);
    die "$$config{target} is on unexpected $version\n" if $version ne $$config{version};
    die "No release found for $$config{target}\n" unless defined($release);
    return int($release);
}

sub update_fedora_fedora {
    my ($config) = @_;

    # Specfile
    my (@in, @out);
    my $actions = 0;
    my $specfile = "termy-$$config{product}.spec";

    open(FH, '<', $specfile) or die;
    chomp(@in = <FH>);
    close(FH);

    while (@in) {
        $_ = shift @in;

        if (m/^Version: (.*)$/) {
            push @out, "Version: $$config{version}";
            ++$actions;
            next;
        }
        if (m/^Release: \d+(.*)$/) {
            push @out, "Release: $$config{release}$1";
            ++$actions;
            next;
        }
        if (m/^Source: (.*)\//) {
            push @out, "Source: $1/termysequence-$$config{product}-\%{version}.tar.xz";
            ++$actions;
            next;
        }
        if (m/^\s*# Patches here/) {
            push @out, $_;
            shift @in while $in[0] =~ m/^Patch\d+:/;
            my $count = 1;
            foreach my $patch (@{$$config{series}}) {
                push @out, "Patch$count: $patch";
                ++$count;
            }
            ++$actions;
            next;
        }
        if (m/^%changelog/) {
            push @out, $_;

            while (@in) {
                # Remove stanzas with same release
                last unless $in[0] =~ m/$$config{version}-$$config{release}$/;
                shift @in;
                shift @in while @in && $in[0] !~ /^\*/;
            }

            my $datespec = time2str("%a %b %d %Y", time);
            push @out, "* $datespec $$config{fullname} <$$config{email}> - $$config{version}-$$config{release}";
            push @out, map("- $_", @{$$config{log}});
            push @out, '';
            ++$actions;
            next;
        }
        push @out, $_;
    }
    close(FH);
    die unless $actions == 5;

    open(FH, '>', $specfile);
    print FH map("$_\n", @out);
    close(FH);

    # Patches
    system("cp $$config{phome}/patches/$_ .") and die for @{$$config{series}};

    system("git add .") and die;
    print "\t\tUpdated specfile to $$config{version}-$$config{release}\n";
}

sub update_fedora_obs {
    my ($config, $branch) = @_;

    # Specfile
    my @lines;
    my $actions = 0;

    open(FH, '<', "termy-$$config{product}.spec") or die;
    while (<FH>) {
        chomp;
        if (m/^Source:( +)/) {
            push @lines, "Source:${1}termysequence-$$config{product}_\%{version}.orig.tar.xz";
            ++$actions;
            next;
        }
        push @lines, $_;
    }
    close(FH);
    die unless $actions == 1;

    my $updir = "$$config{phome}/upstreams/obs-$$config{product}";
    chdir "$updir/" or die;

    (my $obsrepo = "Fedora_$branch") =~ s/_f?(.)/_\U$1/;
    open(FH, '>', "termy-$$config{product}-$obsrepo.spec");
    print FH map("$_\n", @lines);
    close(FH);

    # Patches
    if ($branch eq 'rawhide') {
        foreach my $patch (@{$$config{series}}) {
            my $needadd = ! -f $patch;
            system("cp $$config{phome}/patches/$patch .") and die;
            system("osc add $patch") and die if $needadd;
        }
    }
}

sub update_fedora {
    my ($self, $config) = @_;

    my $updir = "$$config{phome}/upstreams/fedora-$$config{product}";
    chdir "$updir/" or die;

    foreach my $branch (glob('*')) {
        print "\tProcessing branch $branch...\n";
        chdir "$updir/$branch" or die;
        update_fedora_fedora($config);
        update_fedora_obs($config, $branch);
    }

    $$self{did_fedora} = 1;
    $$self{did_obs} = 1;
}

#
## OpenSUSE
#
sub update_opensuse_obs {
    my ($config, $branch) = @_;

    # Specfile
    my @lines;
    my $actions = 0;
    my $specfile = "termy-$$config{product}.spec";

    open(FH, '<', $specfile) or die;
    while (<FH>) {
        chomp;
        if (m/^Version: (.*)$/) {
            push @lines, "Version: $$config{version}";
            ++$actions;
            next;
        }
        if (m/^Release: \d+(.*)$/) {
            push @lines, "Release: $$config{release}$1";
            ++$actions;
            next;
        }
        if (m/^Source:( +)/) {
            push @lines, "Source:${1}termysequence-$$config{product}_\%{version}.orig.tar.xz";
            ++$actions;
            next;
        }
        if (m/^\s*# Patches here/) {
            push @lines, $_;
            my $count = 1;
            foreach my $patch (@{$$config{series}}) {
                push @lines, "Patch$count: $patch";
                ++$count;
            }
            ++$actions;
            next;
        }
        push @lines, $_ unless m/^Patch\d+: /;
    }
    close(FH);
    die unless $actions == 4;

    open(FH, '>', $specfile);
    print FH map("$_\n", @lines);
    close(FH);

    my $updir = "$$config{phome}/upstreams/obs-$$config{product}";
    chdir "$updir/" or die;

    open(FH, '>', "termy-$$config{product}-openSUSE_$branch.spec");
    print FH map("$_\n", @lines);
    close(FH);

    # Patches
    foreach my $patch (@{$$config{series}}) {
        my $needadd = ! -f $patch;
        system("cp $$config{phome}/patches/$patch .") and die;
        system("osc add $patch") and die if $needadd;
    }

    print "\t\tUpdated specfile to $$config{version}-$$config{release}\n";
}

sub update_opensuse {
    my ($self, $config) = @_;

    my $updir = "$$config{phome}/targets/opensuse-$$config{product}/files";
    chdir "$updir/" or die;

    foreach my $branch (glob('*')) {
        print "\tProcessing branch $branch...\n";
        chdir "$updir/$branch" or die;
        update_opensuse_obs($config, $branch);
    }

    $$self{did_obs} = 1;
}

#
## this
#
sub new {
    my $class = shift;
    my $self = {};
    $$self{changes} = {};
    $$self{upstreams} = [];
    return bless $self, $class;
}

sub perform {
    my ($self, $config) = @_;
    $self->update_arch($config) if $$config{distro} eq 'arch';
    $self->update_debian($config) if $$config{distro} eq 'debian';
    $self->update_fedora($config) if $$config{distro} eq 'fedora';
    $self->update_opensuse($config) if $$config{distro} eq 'opensuse';

    foreach my $change (@{$$config{log}}) {
        push @{$$self{changes}->{$change}}, $$config{distro};
    }
}

sub read_release {
    my ($self, $config) = @_;

    return $self->read_arch_release($config) if $$config{distro} eq 'arch';
    return $self->read_debian_release($config) if $$config{distro} eq 'debian';
    return $self->read_specfile_release($config, 'rawhide') if $$config{distro} eq 'fedora';
    return $self->read_specfile_release($config, 'Tumbleweed') if $$config{distro} eq 'opensuse';
}

sub finish_fedora {
    my ($config) = @_;

    my $updir = "$$config{phome}/upstreams/fedora-$$config{product}";
    chdir "$updir/" or die;

    foreach my $branch (glob('*')) {
        chdir "$updir/$branch" or die;
        # Clean up obsolete patches
        for (glob("*.patch")) {
            system("git rm -f $_") and die unless -f "$$config{phome}/patches/$_";
        }
    }
}

sub finish_obs {
    my ($config, $changes) = @_;

    my $updir = "$$config{phome}/upstreams/obs-$$config{product}";
    chdir "$updir/" or die;

    # Edit changes file
    open(FH, '<', "termy-$$config{product}.changes") or die;
    my @lines = <FH>;
    close(FH);

    open(FH, '>', "termy-$$config{product}.changes") or die;
    print FH "-------------------------------------------------------------------\n";
    my $datespec = time2str("%a %b %e %H:%M:%S %Z %Y", time, 'UTC');
    print FH "$datespec - $$config{fullname} <$$config{email}>\n";
    print FH "\n";
    print FH map("- $_\n", @$changes);
    print FH "\n";
    print FH @lines;
    close(FH);

    # Clean up obsolete patches
    for (glob("*.patch")) {
        system("osc remove --force $_") and die unless -f "$$config{phome}/patches/$_";
    }
}

sub finish {
    my ($self, $config) = @_;
    my $changes = [];

    foreach my $change (keys %{$$self{changes}}) {
        my @distros = @{$$self{changes}->{$change}};
        if (@distros > 1) {
            push @$changes, $change;
        } else {
            push @$changes, "$distros[0]: $change";
        }
    }

    finish_fedora($config) if exists $$self{did_fedora};
    finish_obs($config, $changes) if exists $$self{did_obs};
}

1;
