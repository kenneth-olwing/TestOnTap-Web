use strict;
use warnings;

# expected to be in core
#
use FindBin qw($Bin);
use Test::More;

# expected to be in our lib locations
# 
use lib ("$Bin/../../lib", "$Bin/../../local/lib/perl5");
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