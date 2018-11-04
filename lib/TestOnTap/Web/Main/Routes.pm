package TestOnTap::Web::Main::Routes;

use strict;
use warnings;

use TestOnTap::Web::Config;
use TestOnTap::Web::TestResult;
use File::Basename;
use Data::Dump qw(pp);

use Dancer2 appname => 'TestOnTap-Web';

prefix undef;

get '/' => sub
	{
		my $autoupd = cookie('autoupd');
		cookie(autoupd => true, http_only => false) unless defined($autoupd);
		
		my $isDev = config()->{environment} eq 'development' || query_parameters->get('dev');
		template('main',
			{
				dotMin => $isDev ? '' : '.min',
				dev => $isDev ? 1 : 0,
			});
	};

get '/download/result/:result' => sub
	{
		my $result = route_parameters->get('result');
		send_file("$appconfig->{datadir}/results/$result", system_path => 1);
	};

get '/download/suiteartifact' => sub
	{
		my $zipFile = query_parameters->get('zipfile');
		my $test = query_parameters->get('test');
		my $sa = query_parameters->get('sa');
		my $tr = TestOnTap::Web::TestResult->new("$appconfig->{datadir}/results/$zipFile");
		my $suiteArtifactContents = $tr->getSuiteArtifactContentsForTest($test, $sa);
		send_file(\$suiteArtifactContents, filename => basename($sa));
	};

true;
