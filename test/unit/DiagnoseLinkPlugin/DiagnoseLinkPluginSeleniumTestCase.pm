package DiagnoseLinkPluginSeleniumTestCase;

use strict;
use warnings;

use Error qw(:try);
use Foswiki::Func;
use Foswiki::Plugins::TasksAPIPlugin;
use Foswiki::Plugins::TasksAPIPlugin::Task;
use Selenium::Remote::WDKeys;
use ModacSeleniumTestCase();
our @ISA = qw(ModacSeleniumTestCase);

sub new {
  my ($class, @args) = @_;
  my $self = shift()->SUPER::new('DiagnoseLinkPluginSeleniumTests', @args);
  return $self;
}

sub set_up {
  my $this = shift;
  $this->SUPER::set_up(@_);
}

sub tear_down {
  my $this = shift;
  $this->SUPER::tear_down(@_);
}

sub verify_bracketTopicLinks {
  my $this = shift;

  my $topic = 'BracketTopicLinks';
  my $missingTopic = 'BracketTopicLinksMissing';
  my $text = "[[$this->{test_web}.$missingTopic]]";
  $this->becomeSeleniumUser();
  Foswiki::Func::saveTopic($this->{test_web}, $topic, undef, $text);
  $this->assertElementIsPresent('.foswikiTopic a.foswikiNewLink');
}

sub verify_regularTopicLinks {
  my $this = shift;

  my $topic = 'BracketTopicLinks';
  my $missingTopic = 'BracketTopicLinksMissing';
  my $text = "<a href=\"/$this->{test_web}/$missingTopic\">Test Link</a>";
  $this->becomeSeleniumUser();
  Foswiki::Func::saveTopic($this->{test_web}, $topic, undef, $text);
  $this->assertElementIsPresent('.foswikiTopic a.foswikiNewLink');
}


1;
