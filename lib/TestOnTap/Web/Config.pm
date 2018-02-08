package TestOnTap::Web::Config;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw( $config $appconfig );
our @EXPORT_OK = qw( appconfig_init );

use TestOnTap::Web::Util qw(slashify);

use File::Spec;

our $config;
our $appconfig = {};

sub appconfig_init
{
	my $cfg = shift;
	
	$config = $cfg;
	
	my $appname = $cfg->{appname};
	my $appdir = $cfg->{appdir};
	
	$appconfig = $cfg->{$appname}; 
	die("Missing configuration for '$appname'\n") unless $appconfig;
	
	my $datadir = $appconfig->{datadir};
	die("Missing configuration for '$appname/datadir'\n") unless $datadir;
	$datadir = "$appdir/$datadir" unless File::Spec->file_name_is_absolute($datadir);
	$datadir = slashify(File::Spec->rel2abs($datadir));
	mkdir($datadir);
	die("Configuration '$appname/datadir': no such directory: '$datadir'\n") unless -d $datadir; 
	$appconfig->{datadir} = $datadir;
}

1;
