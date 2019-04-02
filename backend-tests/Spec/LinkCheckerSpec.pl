use Foswiki::Plugins::DiagnoseLinkPlugin::LinkCheckerInstance;
use MockAttachmentService;
use MockWikiDocumentService;
use Test::Deep;

describe "The LinkChecker" => sub {
    my ($wikiDocumentService, $attachmentService);
    my $linkChecker;

    before each => sub {
        $wikiDocumentService = MockWikiDocumentService->new();
        $attachmentService = MockAttachmentService->new();

        $linkChecker = Foswiki::Plugins::DiagnoseLinkPlugin::LinkCheckerInstance->new(
            {
                logger => undef,
                wikiDocumentService => $wikiDocumentService,
                attachmentService => $attachmentService,
            },
            {
                DefaultUrlHost => 'https://defaulturlhost',
                TrashWebName => 'Garbage',
                HomeTopicName => 'HomeSweetHome',
            },
            'TestWeb',
            'TestTopic',
        );
    };

    describe "handling topics" => sub {
        describe "when given absolute links" => sub {
            it "detects an existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('https://testwiki.de/TestWeb/TestTopic');
                ok(!$isBadLink);
                ok($targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'TestTopic');
                ok(!defined $file);
            };
            it "detects a non-existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('https://testwiki.de/TestWeb/BadTestTopic');
                ok($isBadLink);
                ok(!$targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'BadTestTopic');
                ok(!defined $file);
            };
            it "detects external links" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('https://anotherwiki.de/TestWeb/TestTopic');
                ok(!$isBadLink);
                ok(!$targetExists);
                ok(!defined $web);
                ok(!defined $topic);
                ok(!defined $file);
            };
        };
        describe "when given path-links" => sub {
            it "detects an existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('/TestWeb/TestTopic');
                ok(!$isBadLink);
                ok($targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'TestTopic');
                ok(!defined $file);
            };
            it "detects a non-existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('/TestWeb/BadTestTopic');
                ok($isBadLink);
                ok(!$targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'BadTestTopic');
                ok(!defined $file);
            };
        };
        describe "when given relative links" => sub {
            it "detects an existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('TestWeb/TestTopic');
                ok(!$isBadLink);
                ok($targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'TestTopic');
                ok(!defined $file);
            };
            it "detects a non-existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('TestWeb/BadTestTopic');
                ok($isBadLink);
                ok(!$targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'BadTestTopic');
                ok(!defined $file);
            };
        };
    };
    describe "handling attachments" => sub {
        describe "when given absolute links" => sub {
            it "detects an existing topic and attachment" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('https://testwiki.de/pub/TestWeb/TestTopic/file.txt');
                ok(!$isBadLink);
                ok($targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'TestTopic');
                ok($file eq 'file.txt');
            };
            it "detects a non-existing attachment" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('https://testwiki.de/pub/TestWeb/TestTopic/anotherfile.txt');
                ok($isBadLink);
                ok(!$targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'TestTopic');
                ok($file eq 'anotherfile.txt');
            };
            it "detects a non-existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('https://testwiki.de/pub/TestWeb/BadTestTopic/file.txt');
                ok($isBadLink);
                ok(!$targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'BadTestTopic');
                ok($file eq 'file.txt');
            };
            it "detects external links" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('https://anotherwiki.de/pub/TestWeb/TestTopic/file.txt');
                ok(!$isBadLink);
                ok(!$targetExists);
                ok(!defined $web);
                ok(!defined $topic);
                ok(!defined $file);
            };
        };
        describe "when given path-links" => sub {
            it "detects an existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('/pub/TestWeb/TestTopic/file.txt');
                ok(!$isBadLink);
                ok($targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'TestTopic');
                ok($file eq 'file.txt');
            };
            it "detects a non-existing topic" => sub {
                my ($isBadLink, $targetExists, $web, $topic, $file) = $linkChecker->check('/pub/TestWeb/BadTestTopic/file.txt');
                ok($isBadLink);
                ok(!$targetExists);
                ok($web eq 'TestWeb');
                ok($topic eq 'BadTestTopic');
                ok($file eq 'file.txt');
            };
        };
    };
};

