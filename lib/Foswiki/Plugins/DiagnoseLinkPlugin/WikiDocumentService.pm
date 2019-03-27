package Foswiki::Plugins::DiagnoseLinkPlugin::WikiDocumentService;

use strict;
use warnings;

use Foswiki::Func;

sub new {
    my ($class, $injections) = @_;

    return bless {}, $class;
}

sub getScriptUrlPath {
    shift;
    return Foswiki::Func::getScriptUrlPath(@_);
}

sub getScriptUrl {
    shift;
    return Foswiki::Func::getScriptUrl(@_);
}

sub normalizeWebTopicName {
    shift;
    return Foswiki::Func::normalizeWebTopicName(@_);
}

sub topicExists {
    shift;
    return Foswiki::Func::topicExists(@_);
}

1;
