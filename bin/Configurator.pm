package Configurator;

use warnings;
use strict;

sub new {
    my ($class, $product) = @_;

    my $self = {};
    $$self{ghome} = $ENV{TERMY_HOME} || "$ENV{HOME}/git/termysequence";
    chomp($$self{phome} = `pwd`);
    chomp($$self{email} = `git config user.email`);
    chomp($$self{fullname} = `git config user.name`);

    $$self{product} = $product;
    chomp($$self{version} = `cat version`);

    return bless $self, $class;
}

sub extend {
    my $parent = shift;
    my $self = {};
    $$self{$_} = $$parent{$_} for keys %$parent;

    while (@_) {
        my $key = shift;
        $$self{$key} = shift;
    }
    return bless $self, ref $parent;
}

1;
