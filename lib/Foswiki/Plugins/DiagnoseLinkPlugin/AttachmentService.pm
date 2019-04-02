package Foswiki::Plugins::DiagnoseLinkPlugin::AttachmentService;

use strict;
use warnings;

use Foswiki::Func;

sub new {
    my ($class, $injections) = @_;

    return bless {}, $class;
}


sub getPubUrlPath {
    shift;
    return Foswiki::Func::getPubUrlPath(@_);
}

sub getPubUrl {
    shift;
    return Foswiki::Func::getPubUrl(@_);
}

sub attachmentExists {
    shift;
    return Foswiki::Func::attachmentExists(@_);
}

1;
