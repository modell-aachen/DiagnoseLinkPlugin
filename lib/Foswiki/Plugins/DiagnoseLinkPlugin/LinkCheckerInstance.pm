package Foswiki::Plugins::DiagnoseLinkPlugin::LinkCheckerInstance;

use strict;
use warnings;

use Encode;
use HTML::Entities;

sub new {
    my ($class, $injections, $cfg, $currentWeb, $currentTopic) = @_;

    my $this = {
        logger => $injections->{logger},
        wikiDocumentService => $injections->{wikiDocumentService},
        attachmentService => $injections->{attachmentService},
        currentWeb => $currentWeb,
        currentTopic => $currentTopic,
        cfg => $cfg,
    };

    my $viewUrl = $this->{wikiDocumentService}->getScriptUrl(undef, undef, 'view'); # $meta->expandMacros('%SCRIPTURL{"view"}%');
    my $viewUrlPath = $this->{wikiDocumentService}->getScriptUrlPath(undef, undef, 'view'); # $meta->expandMacros('%SCRIPTURLPATH{"view"}%');

    my $attachUrl = $this->{attachmentService}->getPubUrlPath($currentWeb, $currentTopic); #$meta->expandMacros('%ATTACHURL%');
    my $attachUrlPath = $this->{attachmentService}->getPubUrlPath($currentWeb, $currentTopic, undef, absolute => 1); #$meta->expandMacros('%ATTACHURLPATH%');
    my $pubUrlPath = $this->{attachmentService}->getPubUrlPath(); #$meta->expandMacros('%PUBURLPATH%');
    my $pubUrl = $this->{attachmentService}->getPubUrlPath(undef, undef, undef, absolute => 1); #$meta->expandMacros('%PUBURL%');

    my $root = $this->{wikiDocumentService}->getScriptUrlPath();

    my $rootSuperQ = $root =~ s/bin//r;
    $rootSuperQ = quotemeta("$rootSuperQ/..");

    my $scriptUrlExtra = $viewUrl =~ s/\/bin\/view//r;

    # /pub
    my $attachUrlExtra = $attachUrl =~ s/$rootSuperQ//r;
    my $attachUrlPathExtra = $attachUrlPath =~ s/$rootSuperQ//r;
    my $pubUrlExtra = $pubUrl =~ s/$rootSuperQ//r;
    my $pubUrlPathExtra = $pubUrlPath =~ s/$rootSuperQ//r;

    $this->{isFileRegexp} = qr/^(\Q$attachUrl\E|\Q$attachUrlExtra\E|\Q$attachUrlPath\E|\Q$attachUrlPathExtra\E|\Q$pubUrl\E|\Q$pubUrlExtra\E|\Q$pubUrlPath\E|\Q$pubUrlPathExtra\E)/;
    $this->{isTopicRegexp} = qr/^(\Q$viewUrl\E|\Q$scriptUrlExtra\E|\Q$viewUrlPath\E)/;
    $this->{isScriptRegexp} = qr/^\Q$root\E/;
    $this->{pathRegexp} = qr/^(\Q$pubUrl\E|\Q$pubUrlPath\E|\Q$viewUrl\E|\Q$viewUrlPath\E)/;
    $this->{defaultUrlHostRegexp} = qr/^\Q$this->{cfg}->{DefaultUrlHost}\E/;

    bless $this, $class;
    return $this;
}

sub check {
    my ($this, $href) = @_;

    $href = urlDecode($href);
    $href = decode_entities($href);

    # skip anchors, empty links, ...
    return if $href =~ m/^(?:#|\s*)$/;

    my $isFile = $href =~ m/$this->{isFileRegexp}/;
    my $isTopic = 0;
    my $isRelative = 0;
    unless ($isFile) {
        $isTopic = $href =~ m/$this->{isTopicRegexp}/;
        # ignore anything else starting with /bin
        $isTopic = $href !~ $this->{isScriptRegexp} unless $isTopic;

        # Relative links to topics within the current web
        if ($href =~ /^[A-Z]/ && $href !~ /[\/\.]/) {
            $isTopic = 1;
            $isRelative = 1;
            $href = "$this->{currentWeb}.$href";
        }
    }

    return unless $isFile || $isTopic;

    # strip off "bloat"
    my $webtopic = $href;
    $webtopic =~ s/$this->{pathRegexp}//;
    $webtopic =~ s/$this->{defaultUrlHostRegexp}//;
    $webtopic =~ s/^\///;
    $webtopic =~ s/[\?;#].*$//;
    return unless $webtopic =~ /^[A-Z]/;

    my $isBadLink = 0;
    my ($targetExists, $web, $topic, $file);
    if ($isTopic) {
        ($web, $topic) = $this->{wikiDocumentService}->normalizeWebTopicName(undef, $webtopic);
        $targetExists = $this->{wikiDocumentService}->topicExists($web, $topic);
        if (!$targetExists || $this->_isInhibitedTrashTarget($web, $topic)) {
            $isBadLink = 1;
        }
    } else {
        my @parts = split(/\//, $webtopic);
        $file = pop @parts;
        ($web, $topic) = $this->{wikiDocumentService}->normalizeWebTopicName(undef, join('/', @parts));
        $targetExists = $this->{attachmentService}->attachmentExists($web, $topic, $file);
        if (!$targetExists || $this->_isInhibitedTrashTarget($web, $topic, $file)) {
            $isBadLink = 1;
        }
    }
    return ($isBadLink, $targetExists, $web, $topic, $file);
}

sub _isInhibitedTrashTarget {
    my ($this, $web, $topic, $file) = @_;

    my $isLinkToTrash = $web =~ m#^\Q$this->{cfg}->{TrashWebName}\E(?:/|$)#;
    return 0 unless $isLinkToTrash;

    my $weAreInTargetWeb = $web eq $this->{currentWeb};
    my $weAreAtTargetTopic = $topic eq $this->{currentTopic};
    return 0 if $weAreInTargetWeb && $weAreAtTargetTopic;

    return 1 if $file;

    my $isLinkToTrashRoot = $web eq $this->{cfg}->{TrashWebName};
    if($isLinkToTrashRoot) {
        return 0 if $topic eq $this->{cfg}->{HomeTopicName};
        return 0 if $topic eq 'WebTopicList';
        return 0 if $topic eq 'TrashAttachment';
    }

    my $weAreInTrashRoot = $this->{cfg}->{TrashWebName} eq $this->{currentWeb};
    if($weAreInTrashRoot) {
        return 0 if $this->{currentTopic} eq 'WebTopicList' || $this->{currentTopic} eq $this->{cfg}->{HomeTopicName};
    }

    return 1;
}

sub urlDecode {
    # Unfortunately we may only decode %xy escapes, because urls often have
    # mixed encodings:
    # %ATTACHURL%/\x{256}.jpg will be %-encoded-utf-8 for the pub-url, but the
    # attachment's name will be perl.
    # We must, however, decode the whole sequence, since a single utf-8 code point
    # is encoded in multiple bytes.
    return $_[0] =~ s/((?:%[0-9A-Fa-f]{2})+)/urlDecodeChunk($1)/egr;
}

# Like Foswiki::urlDecode, but uses FB_CROAK.
sub urlDecodeChunk {
    my ($text) = @_;

    $text =~ s/%([\da-fA-F]{2})/chr(hex($1))/ge;
    eval {
        $text = Encode::decode('UTF-8', $text, Encode::FB_CROAK);
    };
    return $text;
}

1;
