package Foswiki::Plugins::DiagnoseLinkPlugin;

use strict;
use warnings;

use Encode;
use Foswiki::Func;
use Foswiki::Meta;
use Foswiki::Plugins;
use HTML::Entities;

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
  my $rootSuperQ = quotemeta("$root/..");

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
  $attachUrlExtra =~ s/$rootSuperQ//;
  my $attachUrlPathExtra = $attachUrlPath;
  $attachUrlPathExtra =~ s/$rootSuperQ//;
  my $pubUrlExtra = $pubUrl;
  $pubUrlExtra =~ s/$rootSuperQ//;
  my $pubUrlPathExtra = $pubUrlPath;
  $pubUrlPathExtra =~ s/$rootSuperQ//;

  # /
  $root =~ s/bin//;
  my $scriptUrlExtra = $scriptUrl;
  $scriptUrlExtra =~ s/\/bin\/view//;

  my $missingContent = $Foswiki::cfg{Plugins}{DiagnoseLinkPlugin}{MissingAttachmentClass} || 'missingContent';
  $missingContent =~ s/^\.+//;

  while ($html =~ /(<a[^>]+>[^<]*<\/a[^>]*>)/g) {
    my $link = $1;
    my $href = $1 if $link =~ /href=["']([^"']+)["']/i;
    $href = '' unless defined $href;
    my $decoded = $href;
    $decoded =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

    # extract the title information so that we can use it as possible topic title
    my $title = '';
    $title = $1 if $link =~ />([^<]*)<\/a>$/i;
    $title = $1 if !$title && $link =~ /title=["']([^"']+)["']/i;
    $title = HTML::Entities::decode_entities($title);
    $title =~ s/^\s*//g;
    $title =~ s/\s*$//g;

    # Decoding has some problems if there are non encoded characters (e.g. umlauts)
    # in the string (#14506). If the length did not change after decoding
    # we assume that the original string was not encoded and we keep it.
    if(length($decoded) != length($href)) {
      eval {
        $decoded = Encode::decode('UTF-8', $decoded, Encode::FB_CROAK);
      };

      $href = $decoded;
    }

    # skip anchors, empty links, ...
    next if $href =~ /^(#|\s*)$/;

    my $class = '';
    $class = $1 if $link =~ /(class=["'][^"']+["'])/;

    # skip already handled links
    next if $class =~ /foswikiNewLink/;
    next if $class =~ /modacNewLink/;

    my $isFile = $href =~ /^(\Q$attachUrl\E|\Q$attachUrlExtra\E|\Q$attachUrlPath\E|\Q$attachUrlPathExtra\E|\Q$pubUrl\E|\Q$pubUrlExtra\E|\Q$pubUrlPath\E|\Q$pubUrlPathExtra\E)/ || 0;
    my $isTopic = 0;
    my $isRelative = 0;
    unless ($isFile) {
      $isTopic = $href =~ /^(\Q$scriptUrl\E|\Q$scriptUrlExtra\E|\Q$scriptUrlPath\E)/ || 0;
      # ignore anything else starting with /bin
      $isTopic = $href =~ /^\Q$root\E(?!bin)/ || 0 unless $isTopic;

      # Relative links to topics within the current web
      if ($href =~ /^[A-Z]/ && $href !~ /[\/\.]/) {
        $isTopic = 1;
        $isRelative = 1;
        $href = "$Foswiki::Plugins::SESSION->{webName}.$href";
      }
    }

    next unless $isFile || $isTopic;

    # strip off "bloat"
    my $webtopic = $href;
    $webtopic =~ s/^(\Q$attachUrl\E|\Q$attachUrlPath\E|\Q$pubUrl\E|\Q$pubUrlPath\E|\Q$scriptUrl\E|\Q$scriptUrlPath\E)//;
    $webtopic =~ s/^\Q$defaultUrl\E//;
    $webtopic =~ s/^\///;
    $webtopic =~ s/[\?;#].*$//;
    next unless $webtopic =~ /^[A-Z]/;

    if ($isTopic) {
      my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $webtopic);
      unless (Foswiki::Func::topicExists($web, $topic)) {
        $title = $topic unless $title;
        $title = Foswiki::urlEncode($title);
        my $newHref = "$scriptUrl/$web/WebCreateNewTopic?topicparent=$curWeb.$curTopic;newtopic=$web.$topic;newtopictitle=$title";
        my $newLink = $link;
        $href =~ s/^$Foswiki::Plugins::SESSION->{webName}\.// if $isRelative;
        $newLink =~ s/\Q$href\E/$newHref/;

        $newLink = _buildLink($newLink, $class, 'foswikiNewLink');
        $_[0] =~ s/\Q$link\E/$newLink/g;
      }
    } else {
      my @parts = split(/\//, $webtopic);
      my $file = pop @parts;
      my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, join('/', @parts));
      unless (Foswiki::Func::attachmentExists($web, $topic, $file)) {
        my $newLink = _buildLink($link, $class, $missingContent);
        $_[0] =~ s/\Q$link\E/$newLink/g;
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
  $newLink =~ s/\Q$classAttribute\E/$newClassAttribute/ if $classAttribute;
  # replace the first occurence of a whitespace with class="foswikiNewLink"
  $newLink =~ s/\s/ $newClassAttribute / unless $classAttribute;
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
