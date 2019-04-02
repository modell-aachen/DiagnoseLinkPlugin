package Foswiki::Plugins::DiagnoseLinkPlugin;

use strict;
use warnings;

use Foswiki::Func;
use Foswiki::Plugins;
use Foswiki::Attrs;

use HTML::Entities;

use Foswiki::Plugins::DiagnoseLinkPlugin::FoswikiLinkCheckerFactory;
use Foswiki::Plugins::DiagnoseLinkPlugin::Indexer;
use Foswiki::Plugins::DiagnoseLinkPlugin::AttachmentService;
use Foswiki::Plugins::DiagnoseLinkPlugin::WikiDocumentService;
use Foswiki::Plugins::ModacHelpersPlugin;
use Foswiki::Plugins::ModacHelpersPlugin::LoggerInstance;

use version;
our $VERSION = version->declare('1.0.0');
our $RELEASE = '1.0.0';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = "A plugin to highlight links to topics or attachments which doesn't exist.";

our $logger = Foswiki::Plugins::ModacHelpersPlugin::LoggerInstance->new();
our $linkCheckerFactory = Foswiki::Plugins::DiagnoseLinkPlugin::FoswikiLinkCheckerFactory->new(
    {
        logger => $logger,
        attachmentService => Foswiki::Plugins::DiagnoseLinkPlugin::AttachmentService->new(),
        wikiDocumentService => Foswiki::Plugins::DiagnoseLinkPlugin::WikiDocumentService->new(),
    },
    {
        DefaultUrlHost => $Foswiki::cfg{DefaultUrlHost},
        TrashWebName => $Foswiki::cfg{TrashWebName},
        HomeTopicName => $Foswiki::cfg{HomeTopicName},
    },
);
our $indexer;

sub initPlugin {
  my ($topic, $web, $user, $installWeb) = @_;

  if ($Foswiki::Plugins::VERSION < 2.0) {
    Foswiki::Func::writeWarning( 'Version mismatch between ',
      __PACKAGE__, ' and Plugins.pm' );
    return 0;
  }

  my $cls = $Foswiki::cfg{Plugins}{DiagnoseLinkPlugin}{MissingAttachmentClass} || 'missingContent';
  $cls = ".$cls" unless $cls =~ /^\./;

  my $js = <<JS;
<script>
(function(\$) {
  \$(document).ready( function() {
    \$('body').on('click', '$cls', function() {
      return false;
    });
  });
})(jQuery);
</script>
JS

  if (Foswiki::Func::getContext()->{SafeWikiSignable}) {
    Foswiki::Plugins::SafeWikiPlugin::Signatures::permitInlineCode($js);
  }

  my $pluginURL = '%PUBURLPATH%/%SYSTEMWEB%/DiagnoseLinkPlugin';
  my $css = "<link rel=\"stylesheet\" type=\"text/css\" media=\"all\" href=\"$pluginURL/diagnose.css\" />";
  Foswiki::Func::addToZone('script', 'DIAGNOSELINKPLUGIN:JS', $js, 'JQUERYPLUGIN');
  Foswiki::Func::addToZone('head', 'DIAGNOSELINKPLUGIN:CSS', $css);

  Foswiki::Plugins::SolrPlugin::registerIndexTopicHandler(
      \&_indexTopicHandler
  );

  return 1;
}

sub _foswikiAttrsFactory {
    return new Foswiki::Attrs(@_);
}

sub _indexTopicHandler {
    unless($indexer) {
        $indexer = Foswiki::Plugins::DiagnoseLinkPlugin::Indexer->new(
            {
                logger => $logger,
                attachmentService => Foswiki::Plugins::DiagnoseLinkPlugin::AttachmentService->new(),
                wikiDocumentService => Foswiki::Plugins::DiagnoseLinkPlugin::WikiDocumentService->new(),
                foswikiAttrsFactory => \&_foswikiAttrsFactory,
                getScriptUrlPath => Foswiki::Func->can('getScriptUrlPath'),
                getPubUrlPath => Foswiki::Func->can('getPubUrlPath'),
                linkCheckerFactory => $linkCheckerFactory,
            },
        );
    }
    return $indexer->indexTopicHandler(@_);
}

sub completePageHandler {
    my($html, $httpHeaders) = @_;

    my $session = $Foswiki::Plugins::SESSION;

    my $missingContent = $Foswiki::cfg{Plugins}{DiagnoseLinkPlugin}{MissingAttachmentClass} || 'missingContent';
    $missingContent =~ s/^\.+//;

    my $linkChecker = $linkCheckerFactory->create($session->{webName}, $session->{topicName});


    while ($html =~ /(<(a|area)\b[^>]+>.*?<\/\2\b[^>]*>)/g) {
        my $link = $1;
        my ($hrefAttrib, $href) = ($1, $3) if $link =~ /\b(href=(["'])([^"']+)\2)/i;
        next unless $href;

        my $class = '';
        $class = $1 if $link =~ /\b(class=["'][^"']+["'])/;

        # skip links with exception class
        next if $class =~ /modacSkipDiagnoseLink/;
        # skip already handled links
        next if $class =~ /foswikiNewLink/;
        next if $class =~ /modacNewLink/;

        my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check($href);
        if($isBadLink) {
            my $newLink;
            my $newClass;
            if($file) {
                $newLink = $link;
                $newClass = $missingContent;
            } else {
                if(!$targetExists) {
                    # extract the title information so that we can use it as possible topic title
                    my $title = '';
                    $title = $1 if $link =~ m/\bdata-topictitle="([^"]+)"/i; # note: CKEditor's "new links" will already have a foswikiNewLink class and thus not be handled by this plugin
                    $title = $1 if !$title && $link =~ m/\bdata-topictitle='([^']+)'/i;
                    $title = $1 if !$title && $link =~ />([^<]*)<\/a>$/i;
                    $title = $2 if !$title && $link =~ /\btitle=(["'])([^"']+)\1/i;
                    $title = HTML::Entities::decode_entities($title);
                    $title =~ s/^\s*//g;
                    $title =~ s/\s*$//g;
                    $title = $topic unless $title;

                    my $newHref = Foswiki::Func::getScriptUrlPath(
                        $web,
                        'WebCreateNewTopic',
                        'view',
                        topicparent => "$session->{webName}.$session->{topicName}",
                        newtopic => "$web.$topic",
                        newtopictitle => $title,
                    );
                    $newLink = $link =~ s#\b\Q$hrefAttrib\E#href="$newHref"#r;

                    $newClass = 'foswikiNewLink';
                } else {
                    $newLink = $link;
                    $newClass = $missingContent;
                }
            }
            $newLink = _addClass($newLink, $class, $newClass);
            $_[0] =~ s/\Q$link\E/$newLink/g;
        }
    }

    while ($html =~ /(<img\b[^>]+>)/g) {
        my $link = $1;
        my ($srcAttrib, $src) = ($1, $3) if $link =~ /\b(src=(["'])([^"']+)\2)/i;
        next unless $src;

        my $class = '';
        $class = $1 if $link =~ /\b(class=(["'])[^"']+\2)/;

        next if $class =~ /modacSkipDiagnoseLink/;

        my ($isBadLink, $taretExists, $web, $topic, $file) = $linkChecker->check($src);
        if($isBadLink) {
            my $placeholder = Foswiki::Func::getPubUrlPath(Foswiki::Plugins::ModacHelpersPlugin::getDeletedImagePlaceholder());
            my $newLink = $link =~ s#\b\Q$srcAttrib\E#data-dlp-$srcAttrib src="$placeholder"#r;
            $_[0] =~ s/\Q$link\E/$newLink/g;
        }
    }
}

sub _addClass {
    my ($link, $oldClassAttribute, $newClass) = @_;

    my $newLink = $link;

    if($oldClassAttribute) {
        my $newClassAttribute = $oldClassAttribute =~ s/(["'])$/ $newClass$1/r;
        $newLink =~ s/\Q$oldClassAttribute\E/$newClassAttribute/;
    } else {
        my $newClassAttribute = "class=\"$newClass\"";
        $newLink =~ s/\s/ $newClassAttribute /;
    }

    return $newLink;
}

1;

__END__
Q.Wiki DiagnoseLinkPlugin - Modell Aachen GmbH

Author: %$AUTHOR%

Copyright (C) 2016 Modell Aachen GmbH

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
