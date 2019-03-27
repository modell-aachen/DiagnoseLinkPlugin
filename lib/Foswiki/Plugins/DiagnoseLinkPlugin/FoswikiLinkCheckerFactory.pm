package Foswiki::Plugins::DiagnoseLinkPlugin::FoswikiLinkCheckerFactory;

use strict;
use warnings;

use Foswiki::Plugins::DiagnoseLinkPlugin::LinkCheckerInstance;
use Foswiki::Func;

sub new {
    my ($class, $injections, $options) = @_;

    my $this = {
        logger => $injections->{logger},
        wikiDocumentService => $injections->{wikiDocumentService},
        attachmentService => $injections->{attachmentService},
        DefaultUrlHost => $options->{DefaultUrlHost},
        TrashWebName => $options->{TrashWebName},
        HomeTopicName => $options->{HomeTopicName},
    };

    bless $this, $class;
    return $this;
}

sub create {
    my ($this, $web, $topic) = @_;

    my $linkChecker = Foswiki::Plugins::DiagnoseLinkPlugin::LinkCheckerInstance->new(
        {
            logger => $this->{logger},
            wikiDocumentService => $this->{wikiDocumentService},
            attachmentService => $this->{attachmentService},
        },
        {
            DefaultUrlHost => $this->{DefaultUrlHost},
            TrashWebName => $this->{TrashWebName},
            HomeTopicName => $this->{HomeTopicName},
        },
        $web,
        $topic,
    );
    return $linkChecker;
}

1;
