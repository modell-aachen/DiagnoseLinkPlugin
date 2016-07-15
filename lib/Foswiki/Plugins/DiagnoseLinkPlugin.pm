package Foswiki::Plugins::DiagnoseLinkPlugin;

use strict;
use warnings;

use Foswiki::Func;
use Foswiki::Meta;
use Foswiki::Plugins;

use version;
our $VERSION = version->declare('1.0.0');
our $RELEASE = '1.0.0';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = "A plugin to highlight links to topics or attachments which doesn't exist.";

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

  return 1;
}

sub completePageHandler {
  my($html, $httpHeaders) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  my $curWeb = $session->{webName};
  my $curTopic = $session->{topicName};

  my $meta = Foswiki::Meta->new($session);
  my $defaultUrl = $Foswiki::cfg{DefaultUrlHost};
  my $root = $Foswiki::cfg{ScriptUrlPath};

  # /bin/../pub
  my $attachUrl = $meta->expandMacros('%ATTACHURL%');
  my $attachUrlPath = $meta->expandMacros('%ATTACHURLPATH%');
  my $pubUrl = $meta->expandMacros('%PUBURL%');
  my $pubUrlPath = $meta->expandMacros('%PUBURLPATH%');

  # /bin/view
  my $scriptUrl = $meta->expandMacros('%SCRIPTURL{"view"}%');
  my $scriptUrlPath = $meta->expandMacros('%SCRIPTURLPATH{"view"}%');

  # /pub
  my $attachUrlExtra = $attachUrl;
  $attachUrlExtra =~ s/$root\/..//;
  my $attachUrlPathExtra = $attachUrlPath;
  $attachUrlPathExtra =~ s/$root\/..//;
  my $pubUrlExtra = $pubUrl;
  $pubUrlExtra =~ s/$root\/..//;
  my $pubUrlPathExtra = $pubUrlPath;
  $pubUrlPathExtra =~ s/$root\/..//;

  # /
  $root =~ s/bin//;
  my $scriptUrlExtra = $scriptUrl;
  $scriptUrlExtra =~ s/\/bin\/view//;

  my $missingContent = $Foswiki::cfg{Plugins}{DiagnoseLinkPlugin}{MissingAttachmentClass} || 'missingContent';
  $missingContent =~ s/^\.+//;

  while ($html =~ /(<a[^>]+>)/g) {
    my $link = $1;
    my $href = $1 if $link =~ /href=["']([^"']+)["']/;
    $href = '' unless defined $href;
    # skip anchors, empty links, ...
    $href = Foswiki::urlDecode($href);
    next if $href =~ /^(#|\s*)$/;

    my $class = $1 if $link =~ /(class=["'][^"']+["'])/;
    $class = '' unless defined $class;
    # skip already handled links
    next if $class =~ /foswikiNewLink/;

    my $isFile = $href =~ /^($attachUrl|$attachUrlExtra|$attachUrlPath|$attachUrlPathExtra|$pubUrl|$pubUrlExtra|$pubUrlPath|$pubUrlPathExtra)/ || 0;
    my $isTopic = 0;
    unless ($isFile) {
      $href =~ /^($scriptUrl|$scriptUrlExtra|$scriptUrlPath)/ || 0;
      # ignore anything else starting with /bin
      $isTopic = $href =~ /^$root(?!bin)/ || 0 unless $isTopic;
    }

    next unless $isFile || $isTopic;

    # strip off "bloat"
    my $webtopic = $href;
    $webtopic =~ s/^($attachUrl|$attachUrlPath|$pubUrl|$pubUrlPath|$scriptUrl|$scriptUrlPath)//;
    $webtopic =~ s/^$defaultUrl//;
    $webtopic =~ s/^\///;
    $webtopic =~ s/[\?;].*$//;
    next unless $webtopic =~ /^[A-Z]/;

    if ($isTopic) {
      my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $webtopic);
      unless (Foswiki::Func::topicExists($web, $topic)) {
        my $newHref = "$scriptUrl/$web/WebCreateNewTopic?topicparent=$curWeb.$curTopic;newtopic=$web.$topic;newtopictitle=$topic";
        my $newLink = $link;
        $newLink =~ s/$href/$newHref/;

        $newLink = _buildLink($newLink, $class, 'foswikiNewLink');
        $_[0] =~ s/$link/$newLink/g;
      }
    } else {
      my @parts = split(/\//, $webtopic);
      my $file = pop @parts;
      my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, join('/', @parts));
      unless (Foswiki::Func::attachmentExists($web, $topic, $file)) {
        my $newLink = _buildLink($link, $class, $missingContent);
        $_[0] =~ s/$link/$newLink/g;
      }
    }
  }
}

sub _buildLink {
  my ($link, $classAttribute, $class) = @_;

  my $newClassAttribute = $classAttribute;
  $newClassAttribute =~ s/(["'])$/ $class$1/ if $newClassAttribute;
  $newClassAttribute = "class=\"$class\"" unless $newClassAttribute;

  my $newLink = $link;
  $newLink =~ s/$classAttribute/$newClassAttribute/ if $classAttribute;
  $newLink =~ s/>$/$newClassAttribute>/ unless $classAttribute;
  return $newLink;
}

1;

__END__
Q.Wiki Tasks API - Modell Aachen GmbH

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
