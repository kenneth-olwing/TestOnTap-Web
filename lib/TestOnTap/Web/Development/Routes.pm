package TestOnTap::Web::Development::Routes;

use strict;
use warnings;

use TestOnTap::Web::Config;
use TestOnTap::Web::TestResult;

use Data::Dump qw(pp);

use Dancer2 appname => 'TestOnTap-Web';

prefix '/development';

post '/kickparser' => sub
	{
		TestOnTap::Web::TestResult->kickParser();
	};
	
get qr(/?) => sub
	{
		"Process: $$";
	};

#get '/inc' => sub
#	{
#		join("<br/>", @INC);
#	};
#
#get '/env' => sub
#	{
#		my @lines = map { "$_ => '$ENV{$_}'" } sort(keys(%ENV));
#		join("<br/>", @lines);
#	};
#
#get '/die' => sub
#	{
#		die("OMG");
#	};
#
#get '/cfg' => sub
#	{
#		join("<br/>", split("\n", pp(config())));
#	};
#
#get '/appcfg' => sub
#	{
#		join("<br/>", split("\n", pp($appconfig)));
#	};
#
#get '/cfg2' => sub
#	{
#		redirect '/development/cfg'; 
#	};
#
#get '/quit' => sub
#	{
#		delayed
#		{
#			flush;
#			content "quitting";
#			done;
#			exit(1);
#		}
#	};
#	
#get '/params' => sub
#	{
#		my $qp = query_parameters;
#		my $rp = route_parameters;
#		my $bp = body_parameters;
#		my $r = request;
#		
#		my $h = $r->headers;
#		my $d = pp(\@_);
#		debug($d);
#		join("<br/>", split("\n", $d));
#	};
#
#get '/upload' => sub
#	{
#		template 'upload';
#	};
#	
#post '/upload' => sub
#	{
#		my $qp = query_parameters;
#		my $rp = route_parameters;
#		my $bp = body_parameters;
#		my $r = request;
#		
#		debug(pp($r));
#		
#		my $file = upload('testresult');
#		die("no $file") unless $file;
#		debug(pp($file));
#		die("no copy") unless $file->copy_to("$appconfig->{datadir}/" . $file->filename());
#		'file uploaded';
#	};
	
true;
