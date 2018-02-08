package TestOnTap::Web::App;

use strict;
use warnings;

use TestOnTap::Web::Util qw(slashify);
use TestOnTap::Web::Config qw(appconfig_init);
use TestOnTap::Web::Logger qw(applogger_init);

use Dancer2 appname => 'TestOnTap-Web';
use TestOnTap::Web::Main::Routes;
use TestOnTap::Web::API::V1::Routes;

appconfig_init(config());
applogger_init
	(
		{
			debug => sub { debug(@_) },
			info => sub { info(@_) },
			warning => sub { warning(@_) },
			error => sub { error(@_) },
		}
	);

require TestOnTap::Web::Development::Routes if config()->{environment} eq 'development';

TestOnTap::Web::TestResult->kickParser(1) if config()->{environment} eq 'production';

1;
