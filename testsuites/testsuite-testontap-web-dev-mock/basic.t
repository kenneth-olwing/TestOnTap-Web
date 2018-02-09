use strict;
use warnings;

# at this point, make files should have set PERL5LIB correctly (via TESTONTAP_PERL5LIB)
#
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

plan(tests => 4);

use_ok('TestOnTap::Web::App');

my $app = TestOnTap::Web::App->to_app();
isa_ok($app, 'CODE');

my $plackTester = Plack::Test->create($app);

my $response = $plackTester->request(GET '/development');
ok($response->is_success(), 'Request: GET /development');
is($response->content(), "Process: $$", 'Expected content');

done_testing();