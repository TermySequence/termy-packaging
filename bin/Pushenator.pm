package Pushenator;

use warnings;
use strict;

sub new {
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub fast_forward {
    my ($self, $config) = @_;

    # Update obs
    my $updir = "$$config{phome}/upstreams/obs-$$config{product}";
    chdir "$updir/" or die;
    print "\tUpdating obs-$$config{product}...\n";
    system("osc update") and die;

    # Copyback: arch
    system("cp $updir/PKGBUILD $$config{phome}/targets/arch-$$config{product}/files/") and die;
    # Copyback: opensuse
    system("cp $updir/termy-$$config{product}.spec $$config{phome}/targets/opensuse-$$config{product}/files/") and die;

    # Update fedora
    chdir "$$config{phome}/upstreams/fedora-$$config{product}/" or die;
    foreach my $branch (glob('*')) {
        chdir "$$config{phome}/upstreams/fedora-$$config{product}/$branch" or die;
        print "\tUpdating fedora-$$config{product}/$branch...\n";
        system("git pull --rebase") and die;
    }
}

sub bump_version {
    my ($self, $config) = @_;

    my $src = "termysequence-$$config{product}-$$config{nextvers}.tar.xz";
    my $obssrc = "termysequence-$$config{product}_$$config{nextvers}.orig.tar.xz";

    die unless -f "$$config{ghome}/$src";

    # Update obs
    chdir "$$config{phome}/upstreams/obs-$$config{product}/" or die;
    system("osc delete $_") and die for glob("*.patch *.dsc *.tar.xz");
    system("cp $$config{ghome}/$src $obssrc") and die;
    system("osc add $obssrc") and die;

    # Update fedora
    chdir "$$config{phome}/upstreams/fedora-$$config{product}/" or die;
    foreach my $branch (glob('*')) {
        chdir "$$config{phome}/upstreams/fedora-$$config{product}/$branch" or die;
        system("fedpkg new-sources $$config{ghome}/$src") and die;
        unlink for glob("*.patch");
        system("git add .") and die;
    }
}

sub push_copr {
    my ($config) = @_;

    my $updir = "$$config{phome}/upstreams/fedora-$$config{product}/rawhide";
    chdir $updir or die;
    system("fedpkg copr-build --nowait ewalsh/termysequence") and die;
}

sub push_fedora {
    my ($config) = @_;

    my $updir = "$$config{phome}/upstreams/fedora-$$config{product}";
    chdir "$updir/" or die;

    # Get commit message
    local $/ = undef;
    open(FH, '<', "$$config{phome}/targets/fedora-$$config{product}/log") or die;
    my $summary = <FH>;
    close(FH);
    $summary =~ s/"/\\"/gs;

    foreach my $branch (glob('*')) {
        print "\tPushing branch $branch...\n";
        chdir "$updir/branch" or die;
        system("git commit -aem \"$summary\"") and die;
        system("fedpkg push") and die;
    }
}

sub push_launchpad {
    my ($config) = @_;

    my $updir = "$$config{phome}/upstreams/debian-$$config{product}/files";
    chdir $updir or die;

    mkdir "$$config{phome}/build";
    chdir "$$config{phome}/build" or die;

    foreach my $dvers (glob("*")) {
        next if $dvers eq 'unstable';

        my $src = "termysequence-$$config{product}-$$config{version}.tar.xz";
        my $obssrc = "termysequence-$$config{product}_$$config{version}.orig.tar.xz";
        symlink "$$config{ghome}/$src", $src;
        symlink "$$config{ghome}/$src", $obssrc;

        my $srcdir = "termysequence-$$config{version}";
        system("rm -rf $srcdir/");
        system("tar Jxf $src");
        system("cp -rL $$config{phome}/targets/$$config{target}/files/$dvers $srcdir/debian");

        chdir $srcdir or die;
        open(FH, '<', 'debian/changelog') or die;
        my @lines = <FH>;
        close(FH);

        die unless $lines[0] =~ m/\(.*-(\d+)\)/;
        my $release = $1;
        $lines[0] =~ s/\((.*-\d+)\)/($1~$dvers)/;
        $lines[0] =~ s/unstable/$dvers/g;

        open(FH, '>', 'debian/changelog') or die;
        print FH @lines;
        close(FH);

        system("debuild -d -S -sa -k$$config{email}") and die;

        chdir "$$config{phome}/build" or die;
        system("dput -f ppa:sigalrm/termysequence termysequence-$$config{product}_$$config{version}-${release}_source.changes") and die;
    }
}

sub push_obs {
    my ($config) = @_;

    my $updir = "$$config{phome}/upstreams/obs-$$config{product}";
    chdir "$updir/" or die;
    system("osc commit") and die;
}

sub perform {
    my ($self, $config) = @_;

    push_copr($config) if $$config{upstream} eq 'copr';
    push_fedora($config) if $$config{upstream} eq 'fedora';
    push_launchpad($config) if $$config{upstream} eq 'launchpad';
    push_obs($config) if $$config{upstream} eq 'obs';
}

1;
