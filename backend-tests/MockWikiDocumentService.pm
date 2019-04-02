package MockWikiDocumentService;

use strict;
use warnings;

use MockService;

our @ISA = ('MockService');

sub new {
    my $class = shift;
    my $this = $class->SUPER::new(
        getScriptUrl => {
            '__view' => 'https://testwiki.de',
            '' => 'https://testwiki.de',
        },
        getScriptUrlPath => {
            '__view' => '',
            '' => '',
        },
        normalizeWebTopicName => {
            '_TestWeb/TestTopic' => ['TestWeb', 'TestTopic'],
            '_TestWeb/BadTestTopic' => ['TestWeb', 'BadTestTopic'],
        },
        topicExists => {
            TestWeb_TestTopic => 1,
            TestWeb_BadTestTopic => 0,
        },
    );

    return $this;
}

sub getScriptUrlPath {
    my $this = shift;

    return $this->_getMockData(@_);
}

sub getScriptUrl {
    my $this = shift;

    return $this->_getMockData(@_);
}

sub normalizeWebTopicName {
    my $this = shift;

    return $this->_getMockData(@_);
}

sub topicExists {
    my $this = shift;

    return $this->_getMockData(@_);
}

1;
