package MockService;

use strict;
use warnings;

sub new {
    my ($class, %data) = @_;

    return bless { data => \%data }, $class;
}

sub _getMockData {
    my $this = shift;

    my $sub = (caller(1))[3] =~ s#.*::##r;

    my $key = join('_', map{ defined $_ ? $_ : '' } @_);
    unless($this->{data}->{$sub} && defined $this->{data}->{$sub}->{$key}) {
        use Devel::StackTrace;
        my $trace = Devel::StackTrace->new();
        my $traceString = $trace->as_string();

        die "Key not defined: {$sub}->{$key}\n$traceString\n";
    }
    my $result = $this->{data}->{$sub}->{$key};
    if(ref $result eq 'ARRAY') {
        return @$result;
    } else {
        return $result;
    }
}

1;
