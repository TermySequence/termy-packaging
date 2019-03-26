#!/usr/bin/perl

use warnings;
use strict;
use Term::ReadLine;

use FindBin;
use lib "$FindBin::Bin";
use Configurator;
use Preparator;
use Pushenator;

$| = 1;
my $term = new Term::ReadLine 'relman';

# my @products = qw/server qt/;
use constant PRODUCTS => qw/server qt/;
use constant REPOS => qw/main v8/;
use constant UPSTREAMS => qw/scratch copr fedora launchpad obs/;
use constant TMPFILE => "/tmp/relman-commit.txt";
use constant EDITOR => $ENV{EDITOR} || 'vi';

my $config;
my $lastpatch = '-1';

#
## Helpers
#
sub prompt_string {
    my ($prompt, $preput, $defval) = @_;
    my $response = $term->readline("$prompt ", $preput);
    exit(3) unless defined($response);
    $response = $defval if defined($defval) && $response eq '';
    return $response;
}

sub prompt_multi {
    my ($prompt, @preput) = @_;
    open(FH, '>', TMPFILE) or die;
    print FH "# $prompt\n";
    print FH map("$_\n", @preput);
    close(FH);

    system(EDITOR . ' ' . TMPFILE) and die;

    open(FH, '<', TMPFILE) or die;
    chomp(my @results = <FH>);
    close(FH);
    return grep($_ && $_ !~ m/^#/, @results);
}

sub prompt_product {
    print "Select product:\n";
    my $idx = 0;
    foreach my $product (PRODUCTS) {
        print "$idx: $product\n";
        ++$idx;
    }
    return (PRODUCTS)[int(prompt_string('?'))];
}

sub prompt_targets {
    chdir "$$config{phome}/targets";
    my @targets = glob("*-$$config{product}");
    my $idx = 0;

    print "Select targets:\n";
    foreach my $target (@targets) {
        print "$idx: $target\n";
        ++$idx;
    }

    my @results;
    foreach my $idx (split(' ', prompt_string('?'))) {
        return @targets if $idx eq 'all';
        push @results, $targets[int($idx)];
    }
    return @results;
}

sub all_targets {
    chdir "$$config{phome}/targets";
    my $product = shift() ? '*' : $$config{product};
    return glob("*-$product");
}

sub prompt_upstream {
    my @upstreams = (UPSTREAMS);
    my $idx = 0;

    print "Select upstream:\n";
    foreach my $upstream (@upstreams) {
        print "$idx: $upstream\n";
        ++$idx;
    }

    $idx = prompt_string('?');
    return '' unless defined($idx) && $idx =~ m/^\d+$/;
    $idx = int($idx);
    return '' unless $idx >= 0 && $idx < @upstreams;
    return $upstreams[$idx];
}

sub prompt_repo {
    my @repos = (REPOS);
    my $idx = 0;

    print "Select source repo:\n";
    foreach my $repo (@repos) {
        print "$idx: $repo\n";
        ++$idx;
    }

    $idx = prompt_string('?');
    return '' unless defined($idx) && $idx =~ m/^\d+$/;
    $idx = int($idx);
    return '' unless $idx >= 0 && $idx < @repos;
    return $repos[$idx];
}

sub prompt_patch {
    chdir "$$config{phome}/patches";
    my @patches = glob("*.patch");
    my $idx = 0;
    my $preput = '0';

    print "Select patch:\n";
    foreach my $patch (@patches) {
        print "$idx: $patch\n";
        $preput = $idx if $patch eq $lastpatch;
        ++$idx;
    }

    while (1) {
        $idx = prompt_string('?', $preput);
        next unless defined($idx) && $idx =~ m/^\d+$/;
        $idx = int($idx);
        last if $idx >= 0 && $idx < @patches;
    }
    $lastpatch = $patches[$idx];
    return ($lastpatch, get_msg_from_patch($lastpatch));
}

sub get_msg_from_patch {
    my $patch = shift;
    my $msg = 'Unknown patched change';
    open(FH, '<', $patch) or die;
    while (<FH>) {
        if (m/^\s+(\S.*)/) {
            chomp($msg = $1);
            last;
        }
        last if m/^---/ || m/^\+\+\+/;
    }
    close(FH);
    die if $msg =~ m/^\s*$/;
    return $msg;
}

#
## Actions
#
sub set_product {
    $$config{product} = prompt_product();
    return 0;
}

sub view_patches {
    foreach my $target (all_targets()) {
        chomp(my $release = `cat $target/release`);
        print "${target} (next release: $$config{version}-$release):\n";

        open(FH, '<', "$target/series") or die;
        print "\tPatches:\n";
        my @patches = <FH>;
        push @patches, "No patches\n" unless @patches;
        print map("\t\t$_", @patches);
        close(FH);

        open(FH, '<', "$target/log") or die;
        print "\tLog:\n";
        my @log = <FH>;
        push @log, "No log\n" unless @log;
        print map("\t\t$_", @log);
        close(FH);
    }
    return 1;
}

sub extract_patch {
    my $repo = prompt_repo();
    return 0 unless $repo;
    my $patch_id = prompt_string('commit id?', 'HEAD');

    if ($repo eq 'v8') {
        chdir "$$config{ghome}/vendor/v8-linux" or die;
    } else {
        chdir "$$config{ghome}" or die;
    }

    chomp(my $lognam = `git log --pretty=format:%f -n1 $patch_id`);
    die if $?;
    $lastpatch = prompt_string('filename?', lc($lognam));
    $lastpatch .= ".patch" unless $lastpatch =~ /\.patch$/;

    my $patch_path = "$$config{phome}/patches/$lastpatch";

    if (-f "$patch_path") {
        return 0 if 'y' ne lc(prompt_string('Patch already exists, overwrite? [n]', '', 'n'));
    }

    system("git log -n1 -p $patch_id >$patch_path");
    print "\tImported $patch_id to patches/$lastpatch\n";

    if ($repo eq 'v8') {
        # Fix up the patch paths
        open(FH, '<', "$patch_path") or die;
        my @lines = <FH>;
        close(FH);

        for (@lines) {
            s|\b([ab])/v8|$1/vendor/v8-linux/v8|g if m/^diff/;
            s|\b([ab])/v8|$1/vendor/v8-linux/v8| if m/^(---|\+\+\+)/;
        }

        open(FH, '>', "$patch_path") or die;
        print FH @lines;
        close(FH);
    }

    # chomp(my $msg = `git log --pretty=format:%s -n1 $patch_id`);
    my $msg = get_msg_from_patch($patch_path);
    print "\t$msg\n";
    return 1;
}

sub import_patch {
    print STDERR "Not implemented\n";
    $lastpatch = '';
    # Place msg at top of patchfile, indented with 4 spaces
    return 1;
}

sub link_patch {
    my ($patch, $msg) = prompt_patch();
    foreach my $target (prompt_targets()) {
        open(FH, '>>', "$target/series") or die;
        print FH "$patch\n";
        close(FH);
        open(FH, '>>', "$target/log") or die;
        print FH "$msg\n";
        close(FH);
        print "\tLinked $patch -> $target\n";
    }
    print "\t$msg\n";
    return 1;
}

sub unlink_patch {
    my ($patch, $msg) = prompt_patch();
    foreach my $target (prompt_targets()) {
        my (@input, @output);
        # Update logs
        open(FH, '<', "$target/log") or die;
        @input = <FH>;
        close(FH);
        @output = grep("$msg\n" ne $_, @input);
        open(FH, '>', "$target/log") or die;
        print FH @output;
        close(FH);

        # Update series
        open(FH, '<', "$target/series") or die;
        @input = <FH>;
        close(FH);
        @output = grep("$patch\n" ne $_, @input);
        open(FH, '>', "$target/series") or die;
        print FH @output;
        close(FH);

        if (@output != @input) {
            print "\tRemoved $patch from $target\n";
        } else {
            print "\tNo action taken for $target\n";
        }
    }

    if ('y' eq lc(prompt_string('Remove patch? [n]', '', 'n'))) {
        unlink "$$config{phome}/patches/$patch" or die "unlink: $!\n";
        print "\tUnlinked $patch\n";
    }
    return 1;
}

sub record_change {
    foreach my $target (prompt_targets()) {
        (my $distro = $target) =~ s/-\w+$//;

        chdir "$target/files/" or die;
        my $patch_id = prompt_string('commit id?', 'HEAD');
        chomp(my $msg = `git log --pretty=format:%s -n1 $patch_id`);
        die if $?;
        chdir "$$config{phome}/targets";

        open(FH, '>>', "$target/log") or die;
        print FH "$msg\n";
        close(FH);
        print "\t$target: $msg\n";
    }
    return 1;
}

sub bump_version {
    my $hint = '';
    open(FH, '<', "$$config{ghome}/CMakeLists.txt") or die;
    while (<FH>) {
        if (m/PROJECT\(.*VERSION ([0-9\.]+)\)/) {
            $hint = $1;
            last;
        }
    }
    close(FH);

    my $nextvers = prompt_string('bump to?', $hint);
    my $msg = "Update to version $nextvers";

    open(FH, '>', "$$config{phome}/version") or die;
    print FH "$nextvers\n";
    close(FH);

    foreach my $target (all_targets()) {
        # Reset series
        truncate "$target/series", 0;

        # Update log
        open(FH, '>>', "$target/log") or die;
        print FH "$msg\n";
        close(FH);
        # Update release
        open(FH, '>', "$target/release") or die;
        print FH "1\n";
        close(FH);
    }

    # Update sources
    my $push = new Pushenator();
    $push->bump_version($config->extend(nextvers => $nextvers));
    $$config{version} = $nextvers;

    return 1;
}

sub collect_keys {
    system("ssh-add ~/.ssh/fedora") and die;
    system("gpg-connect-agent /bye") and die;
    system("gpg -s -b --default-key $$config{email} --output /dev/null /dev/null") and die;

    my $identity;
    open(FH, '<', "$ENV{HOME}/.config/goa-1.0/accounts.conf") or die;
    while (<FH>) {
        $identity = $1, last if m/^Identity=(.*)/;
    }
    close(FH);
    die unless defined($identity);
    for (my $i = 0; $i < 3; ++$i) {
        last if system("kinit $identity") == 0;
    }

    return 0;
}

sub prep_update {
    if ('y' eq lc(prompt_string('Fetch from upstream? [n]', '', 'n'))) {
        my $push = new Pushenator();
        foreach my $product (PRODUCTS) {
            print "● Fast forward $product...\n";
            $push->fast_forward($config->extend(product => $product));
        }
    }

    my $prep = new Preparator();
    foreach my $target (all_targets(1)) {
        my ($distro, $product) = split('-', $target);

        print "● Prepping $target...\n";
        my $release = $prep->read_release($config->extend(
                                              target => $target,
                                              product => $product,
                                              distro => $distro,
                                          ));
        ++$release;
        chdir "$$config{phome}/targets";

        open(FH, '>', "$target/release") or die;
        print FH "$release\n";
        close(FH);
        print "\tNext release is $release\n";

        # Reset log
        truncate "$target/log", 0;
    }

    print "● Done\n";
    return 1;
}

sub stage_update {
    my $prep = new Preparator();

    foreach my $target (prompt_targets()) {
        (my $distro = $target) =~ s/-\w+$//;

        print "● Staging $target...\n";
        open(FH, '<', "$target/series") or die "Failed to open $target/series: $!\n";
        chomp(my @series = <FH>);
        close(FH);
        open(FH, '<', "$target/log") or die "Failed to open $target/log: $!\n";
        chomp(my @log = <FH>);
        close(FH);
        open(FH, '<', "$target/release") or die "Failed to open $target/release: $!\n";
        chomp(my $release = <FH>);
        close(FH);

        @log = prompt_multi("Changelog for $target:", @log);
        if (@log) {
            $prep->perform($config->extend(
                               log => \@log,
                               series => \@series,
                               target => $target,
                               distro => $distro,
                               release => int($release),
                           ));
            chdir "$$config{phome}/targets";
        } else {
            print "● \tNot doing anything for $target\n";
        }
    }

    $prep->finish($config);
    print "● Done\n";
    return 1;
}

sub push_update {
    my $push = new Pushenator($config);

    my $upstream = prompt_upstream();
    return 0 unless $upstream;
    print "● Pushing to $upstream...\n";
    $push->perform($config->extend(upstream => $upstream));

    return 1;
}

sub menu {
    print "--------------------------------\n";
    print "Main menu:\n";
    print "0. Select product (currently $$config{product})\n";
    print "1. View patches\n";
    print "2. Import patch from git\n";
    print "3. Import patch from file\n";
    print "4. Link patch to target\n";
    print "5. Unlink patch from target\n";
    print "6. Record change to distro files\n";
    print "7. Bump version (currently $$config{version})\n";
    print "8. Collect pass phrases\n";
    print "9. Prepare for update\n";
    print "10. Stage an update\n";
    print "11. Commit and push an update\n";
    print "12. Quit\n";

    chomp(my $reply = prompt_string('>'));

    return set_product if $reply eq 0;
    return view_patches if $reply eq 1;
    return extract_patch if $reply eq 2;
    return import_patch if $reply eq 3;
    return link_patch if $reply eq 4;
    return unlink_patch if $reply eq 5;
    return record_change if $reply eq 6;
    return bump_version if $reply eq 7;
    return collect_keys if $reply eq 8;
    return prep_update if $reply eq 9;
    return stage_update if $reply eq 10;
    return push_update if $reply eq 11;
    exit if $reply eq 12;
}

sub main {
    unless (-f 'bin/relman.pl') {
        print STDERR "Run me from the termy-packaging directory\n";
        exit 1;
    }

    $config = new Configurator('qt');
    $$config{prompt_string} = \&prompt_string;

    while (1) {
        if (menu()) {
            print "✔ ";
            my $notused = <STDIN>;
        }
    }
}

main();
