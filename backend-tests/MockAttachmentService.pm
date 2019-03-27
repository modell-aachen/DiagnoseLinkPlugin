package MockAttachmentService;

use strict;
use warnings;

use MockService;

our @ISA = ('MockService');

sub new {
    my $class = shift;
    my $this = $class->SUPER::new(
        getPubUrlPath => {
            TestWeb_TestTopic_absolute_1 => 'https://testwiki.de/pub/TestWeb/TestTopic',
            TestWeb_TestTopic__absolute_1 => 'https://testwiki.de/pub/TestWeb/TestTopic',
            TestWeb_TestTopic => '/pub/TestWeb/TestTopic',
            '' => '/pub',
            '___absolute_1' => 'https://testwiki.de/pub',
        },
        attachmentExists => {
            'TestWeb_TestTopic_file.txt' => 1,
            'TestWeb_BadTestTopic_file.txt' => 0,
            'TestWeb_TestTopic_anotherfile.txt' => 0,
        },
    );

    return $this;
}

sub _getSuperMockData {
    my $this = shift;
    return $this->_getMockData(@_);
}

sub getPubUrlPath {
    my $this = shift;

    return $this->_getMockData(@_);
}

sub getPubUrl {
    my $this = shift;

    return $this->_getMockData(@_);
}

sub attachmentExists {
    my $this = shift;

    return $this->_getMockData(@_);
}

1;

