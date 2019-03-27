package Test;

use strict;
use warnings;

use File::Basename;
use Cwd qw(getcwd);

use utf8;
use Test::Spec;
use Jasmine::Spy;

use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '..', 'qdeploy', 'lib');

sub getSpecs {
    my ($pattern) = @_;

    my $cwd = getcwd();
    chdir dirname(__FILE__);
    my @specs = glob($pattern);
    chdir $cwd;

    return @specs;
}

my @specs = getSpecs("Spec/**Spec.pm Spec/**Spec.pl");

for my $spec (@specs) {
    spec_helper $spec;
}

runtests unless caller;

