package Foswiki::Plugins::DiagnoseLinkPlugin::Indexer;

use strict;
use warnings;

sub new {
    my ($class, $injections) = @_;

    my $this = {
        logger => $injections->{logger},
        linkCheckerFactory => $injections->{linkCheckerFactory},
        wikiDocumentService => $injections->{wikiDocumentService},
        attachmentService => $injections->{attachmentService},
        foswikiAttrsFactory => $injections->{foswikiAttrsFactory},
    };

    bless $this, $class;
    return $this;
}

sub _attributesToList {
    my ($this, $args, $defaultWeb, $defaultTopic) = @_;

    my $attrs = $this->{foswikiAttrsFactory}->( $args );
    return ($attrs->{web} || $defaultWeb, $attrs->{topic} || $defaultTopic, $attrs->{_DEFAULT});
}

sub _addLink {
    my ($this, $linkChecker, $outgoing, $href) = @_;

    return unless $href;

    my ($isBadLink, $targetExists, $targetWeb, $targetTopic, $targetFile) = $linkChecker->check($href);
    if($targetFile) {
        $outgoing->{attachment}->{$isBadLink}->{"$targetWeb.$targetTopic/$targetFile"} = 1;
        $outgoing->{attachmentTopic}->{$isBadLink}->{"$targetWeb.$targetTopic"} = 1;
    } elsif($targetWeb && $targetTopic) {
        $outgoing->{topic}->{$isBadLink}->{"$targetWeb.$targetTopic"} = 1;
    }
}

sub indexTopicHandler {
    my ($this, $indexer, $doc, $web, $topic, $meta) = @_;

    my $origText = $meta->text(); # not using plainified $text param for indexTopicHandler
    my %outgoing = ();
    my $linkChecker = $this->{linkCheckerFactory}->create($web, $topic);

    $origText =~ s#%(?:BASE)?WEB%#$web#g;
    $origText =~ s#%(?:BASE)?TOPIC%#$topic#g;

    $origText =~ s#%SCRIPTURL(?:PATH)?{(.*)}%#$this->{wikiDocumentService}->getScriptUrlPath($this->_attributesToList($1, undef, undef))#ge;
    $origText =~ s#%PUBURL(?:PATH)?({(.*)})?%#$this->{attachmentService}->getPubUrlPath($this->_attributesToList($1, undef, undef))#ge;
    $origText =~ s#%ATTACHURL(?:PATH)?({(.*)})?%#$this->{attachmentService}->getPubUrlPath($this->_attributesToList($1, $web, $topic))#ge;

    while ($origText =~ /(<(a|area)\b[^>]+>)/g) {
        my $link = $1;
        my ($hrefAttrib, $href) = ($1, $3) if $link =~ /\b(href=(["'])([^"']+)\2)/i;
        $this->_addLink($linkChecker, \%outgoing, $href);
    }

    while ($origText =~ /(<img\b[^>]+>)/g) {
        my $link = $1;
        my ($hrefAttrib, $href) = ($1, $3) if $link =~ /\b(src=(["'])([^"']+)\2)/i;
        $this->_addLink($linkChecker, \%outgoing, $href);
    }

    # square brackets
    while ($origText =~ m{\[\[  ([^\]\[\n]+) \]
            (?: \[        # optional link title
            ([^\]\n]+)
            \])?
            \]}gx) {
        $this->_addLink($linkChecker, \%outgoing, $1);
    }

    foreach my $link (keys %{$outgoing{topic}{0}}) {
        next if $link eq "$web.$topic";    # self link is not an outgoing link
        $doc->add_fields(outgoingWiki_lst => $link);
    }

    foreach my $link (keys %{$outgoing{topic}{1}}) {
        $doc->add_fields(outgoingWiki_broken_lst => $link);
    }

    foreach my $link (keys %{$outgoing{attachment}{0}}) {
        $doc->add_fields(outgoingAttachment_lst => $link);
    }

    foreach my $link (keys %{$outgoing{attachment}{1}}) {
        $doc->add_fields(outgoingAttachment_broken_lst => $link);
    }

    foreach my $link (keys %{$outgoing{attachmentTopic}{0}}) {
        $doc->add_fields(outgoingAttachmentTopic_lst => $link);
    }

    foreach my $link (keys %{$outgoing{attachmentTopic}{1}}) {
        $doc->add_fields(outgoingAttachmentTopic_broken_lst => $link);
    }
}

1;
