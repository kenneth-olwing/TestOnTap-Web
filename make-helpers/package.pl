use strict;
use warnings;

# at this point, make files should have set PERL5LIB correctly
#
use Config;
use File::Find;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Hash::Merge::Simple qw(merge);
use Config::Any;
use File::Basename;
use Grep::Query;
use JSON;
use TestOnTap::Web::Util qw(slashify);

exit(main(@ARGV));

##

sub main
{
	my $basedir = shift;
	my $packagename = shift;
	my $packagezip = shift;
	
	die("usage: $0 <basedir> <packagename> <packagezip>")
		if 		@_
			||	!$basedir
			||	!$packagename
			||	!$packagezip;
	
	my $zipTs = (stat($packagezip))[9] || 0;
	my ($latestDepTs, $packables) = searchDeps($basedir);

	mkzip($basedir, $packagezip, $packagename, $packables) if ($latestDepTs > $zipTs);
	
	print "$packagezip\n";

	return(0);
}

sub searchDeps
{
	my $basedir = shift;
	
	my $packablesQuery = Grep::Query->new
		(
<<PQ
	EQ(.dancer)
		OR
	REGEXP{^(bin|lib|LOCAL|public|views)/}
		AND NOT
	(
		REGEXP{^LOCAL/(bin|cache)(/|\$)}
			OR
		REGEXP{^bin/.*_dev\.bat\$}
	)
PQ
		);

	my $nonpackablesQuery = Grep::Query->new
		(
<<PQ
	REGEXP{^make-helpers/}
		OR
	REGEXP{^cpanfile(\.snapshot)?\$}
		OR
	EQ(GNUMakefile)
		OR
	EQ(config.json)
		OR
	EQ(environments/production.json)
PQ
		);

	my $latestTs = 0;
	my %packables;
			
	find(
			{
				no_chdir => 1,
				wanted => sub
					{
						my $fn = $File::Find::name;
						$fn =~ s/^\Q$basedir\E.//;
						my $isPackable = $packablesQuery->qgrep($fn);
						my $isNonPackable = $nonpackablesQuery->qgrep($fn);
						if ($isPackable || $isNonPackable)
						{
							my $ts = (stat($File::Find::name))[9];
							$latestTs = $ts if $ts > $latestTs;
							$packables{slashify($fn, '/')} = slashify($File::Find::name) if $isPackable;
						}
					}
			},
			$basedir
		);
		
	return($latestTs, \%packables);
}

sub mkzip
{
	my $basedir = shift;
	my $zipPath = shift;
	my $packagename = shift;
	my $packables = shift;
	
	print "Packaging...\n";
	
	my $zip = Archive::Zip->new();
	
	$zip->addDirectory($packagename);
	
	foreach my $m (sort(keys(%$packables)))
	{
		$zip->addFileOrDirectory($packables->{$m}, "$packagename/$m")->desiredCompressionLevel(COMPRESSION_LEVEL_BEST_COMPRESSION);
	}

	my $config;
	foreach my $fn (slashify("$basedir/config.json"), slashify("$basedir/environments/production.json"))
	{
		die("Missing file: '$fn'") unless -f $fn;
		my $cfgPair = Config::Any->load_files({ files => [$fn], use_ext => 1});
		my $cfg = $cfgPair->[0]->{$fn};
		$config = merge($config, $cfg);
	}
	$config->{"##COMMENT##"} = "Avoid changing this file. Instead override values using a 'config_local.json' file";
	$zip->addString(to_json($config, {utf8 => 1, pretty => 1, canonical => 1}), "$packagename/config.json")->desiredCompressionLevel(COMPRESSION_LEVEL_BEST_COMPRESSION);

	my $buildContext = <<CTX;
archname=$Config{archname}
perlver=$^V
CTX
	$zip->addString($buildContext, "$packagename/etc/build.context")->desiredCompressionLevel(COMPRESSION_LEVEL_BEST_COMPRESSION);
	
	die("Failed to write '$zipPath': $!") unless $zip->overwriteAs($zipPath) == AZ_OK;
}
