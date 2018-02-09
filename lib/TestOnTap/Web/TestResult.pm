package TestOnTap::Web::TestResult;

use strict;
use warnings;

use TestOnTap::Web::Config;
use TestOnTap::Web::Logger;
use TestOnTap::Web::Util qw(slashify $LIST_SEP);

use Archive::Zip;
use JSON::PP; # XS f-ed up bcoz fork(), probably...
use File::Basename;
use File::Path qw(mkpath);

sub new
{
	my $class = shift;
	my $zipFile = shift;

	my $self;

	my $topName;
	my $summary;
	my $testinfo;
	
	my $zip = Archive::Zip->new($zipFile);
	if ($zip)
	{
		my @memberNames = grep(m#^[^/]+/$#, $zip->memberNames());
		if (@memberNames == 1)
		{
			chop($topName = $memberNames[0]);

			if ($topName =~ m#\.\d{8}T\d{6}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$#)
			{
				my $meta = decode_json(scalar($zip->contents("$topName/testontap/meta.json")));
				
				if ($meta->{format}->{major} == 1)
				{
					$testinfo = decode_json(scalar($zip->contents("$topName/testontap/testinfo.json")));
					if (!$testinfo->{prunedgraph})
					{
						$self = bless
								(
									{
										filename => $zipFile,
										zip => $zip,
										topname => $topName,
										testinfo => $testinfo,
										results => {},
									},
									$class
								);
					}
					else
					{
						appdebug("Only partial result in '$zipFile'");
					}
				}
				else
				{
					appdebug("Unexpected major version in '$zipFile': $meta->{format}->{major}");
				}
			}
			else
			{
				appdebug("Unexpected members in '$zipFile': @memberNames");
			}
		}
		
		appdebug("Invalid result zip '$zipFile'") unless $topName;
	}
	else
	{
		appdebug("Failed to load '$zipFile'");
	}

	return $self;
}

sub validateUpload
{
	my $class = shift;
	my $uploads = shift;

	my %answer;
	if ($uploads)
	{
		$uploads = [ $uploads ] unless ref($uploads) eq 'ARRAY'; 

		my $errors = 0;
		my $warnings = 0;	
		my $count = 0;
		foreach my $upload (@$uploads)
		{
			my $fn = $upload->filename();
			my $tr = $class->new($upload->tempname());
			if ($tr)
			{
				my $topName = $tr->getTopName(); 
				my $copyToFn = "$appconfig->{datadir}/results/$topName.zip";
				if (-e $copyToFn)
				{
					$warnings++;
					$answer{files}->{$fn}->{result} = 1;
					$answer{files}->{$fn}->{msg} = "WARNING: Test result $topName already exists";
				}
				else
				{
					mkpath(dirname($copyToFn));
					if ($upload->copy_to($copyToFn))
					{
						appdebug("Copied upload '$fn' to $copyToFn");
						$count++;
						$answer{files}->{$fn}->{result} = 0;
						$answer{files}->{$fn}->{msg} = "Test result ok";
					}
					else
					{
						$errors++;
						$answer{files}->{$fn}->{result} = 2;
						$answer{files}->{$fn}->{msg} = "ERROR: Copy failed";
					}
				}
			}
			else
			{
				$errors++;
				$answer{files}->{$fn}->{result} = 2;
				$answer{files}->{$fn}->{msg} = "ERROR: invalid test result zip";
			}
		}

		$class->kickParser() if $count;

		$answer{result} = $errors 
							? 2
							: $warnings
								? 1
								: 0;
		$answer{msg} = $answer{result} ? "Errors: $errors, Warnings: $warnings" : "All ($count) test results uploaded ok";
	}
	else
	{
		$answer{result} = 2;
		$answer{msg} = "No uploads found";
	}
		
	return \%answer;
}

sub kickParser
{
	my $class = shift;
	my $force = shift || 0;
	
	my $logdir = slashify($config->{engines}->{logger}->{File}->{log_dir} || $appconfig->{datadir});
	$logdir = slashify("$config->{appdir}/$logdir") unless File::Spec->file_name_is_absolute($logdir); 
	appinfo("Kicking parser with logging in '$logdir' (force=$force)");

	my @cmd = 
		(
			$^X,
			slashify("$config->{appdir}/bin/internal/parse_result_files.pl"),
			'--datadir',
			slashify($appconfig->{datadir}),
			'--logdir',
			$logdir,
		);

	local %ENV = %ENV;
	$ENV{PERL5LIB} = join($LIST_SEP, @INC); 
	
	my $xit = 0;
	if ($force)
	{
		@cmd = (@cmd, '--force');
		$xit = system(@cmd) >> 8;
		appdebug("Ran parser, xit=$xit");
	}
	else
	{
		my $forkpid = fork();
		if (defined($forkpid))
		{
			if ($forkpid == 0)
			{
				# child
				$xit = system(@cmd) >> 8;
				exit($xit);
			}
		}
		else
		{
			apperror("Fork of parser failed!: $!");
		}
	}
	
	return $xit;
}

##

sub getFilename
{
	my $self = shift;

	return $self->{filename};
}

sub getTopName
{
	my $self = shift;

	return $self->{topname};
}

sub getSuiteId
{
	my $self = shift;

	return $self->getMeta()->{suiteid};
}

sub getSuiteName
{
	my $self = shift;

	return $self->getMeta()->{suitename};
}

sub getMeta
{
	my $self = shift;

	$self->{meta} = decode_json($self->{zip}->contents("$self->{topname}/testontap/meta.json")) unless $self->{meta};
	
	return $self->{meta};
}

sub getSummary
{
	my $self = shift;

	$self->{summary} = decode_json($self->{zip}->contents("$self->{topname}/testontap/summary.json")) unless $self->{summary};

	return $self->{summary};
}

sub getTestinfo
{
	my $self = shift;

	$self->{testinfo} = decode_json($self->{zip}->contents("$self->{topname}/testontap/testinfo.json")) unless $self->{testinfo};

	return $self->{testinfo};
}

sub getEnv
{
	my $self = shift;

	$self->{env} = decode_json($self->{zip}->contents("$self->{topname}/testontap/env.json")) unless $self->{env};

	return $self->{env};
}

sub getBegin
{
	my $self = shift;

	return $self->getMeta()->{begin};
}
	
sub getEnd
{
	my $self = shift;

	return $self->getMeta()->{end};
}
	
sub getJobs
{
	my $self = shift;

	return $self->getMeta()->{jobs};
}
	
sub getRunid
{
	my $self = shift;

	return $self->getMeta()->{runid};
}

sub getUname
{
	my $self = shift;

	return $self->getMeta()->{uname};
}

sub getHost
{
	my $self = shift;

	return $self->getMeta()->{host};
}

sub getUser
{
	my $self = shift;

	return $self->getMeta()->{user};
}

sub getPlatform
{
	my $self = shift;

	return $self->getMeta()->{platform};
}

sub getTestCount
{
	my $self = shift;

	return scalar(@{$self->getTestinfo()->{found}});	
}

sub getMicroTestCount
{
	my $self = shift;

	my $microtests = 0;
	my $pass = 0;
	my $fail = 0;
	foreach my $testname (@{$self->getTestNames()})
	{
		my $res = $self->getResultForTest($testname);
		my $testsRun = $res->{tests_run};
		my $testsFailed = scalar(@{$res->{failed}});
		my $testsPassed = $testsRun - $testsFailed;
		$microtests += $testsRun;
		$fail += $testsFailed;
		$pass += $testsPassed;
	}
	
	return ($microtests, $pass, $fail);
}

sub getTestNames
{
	my $self = shift;

	return $self->getTestinfo()->{found};	
}

sub getResultForTest
{
	my $self = shift;
	my $name = shift;
	
	$self->{results}->{$name} = decode_json($self->{zip}->contents("$self->{topname}/testontap/result/$name.json")) unless $self->{results}->{$name};
	
	return $self->{results}->{$name};
}

sub getTapForTest
{
	my $self = shift;
	my $name = shift;
	
	return $self->{zip}->contents("$self->{topname}/testontap/tap/$name.tap");
}

sub getAllPassed
{
	my $self = shift;

	return $self->getSummary()->{all_passed};
}

sub getSuiteArtifacts
{
	my $self = shift;
	
	my @suiteArtifacts;
	my $root = "$self->{topname}/suite/";
	my @memberNames = sort($self->{zip}->memberNames());
	foreach my $member (grep(m#^\Q$root\E#, @memberNames))
	{
		$member =~ s/^\Q$root\E//;
		push(@suiteArtifacts, $member);
	}
	
	return \@suiteArtifacts; 
}

sub getSuiteArtifactNamesForTest
{
	my $self = shift;
	my $name = shift;
	
	my $allSuiteArtifacts = $self->getSuiteArtifacts();
	my @testArtifacts = grep(m#^\Q$name\E/#, @$allSuiteArtifacts);
	$_ =~ s#^\Q$name\E/## foreach (@testArtifacts);
	
	return \@testArtifacts;
}

sub getSuiteArtifactContentsForTest
{
	my $self = shift;
	my $name = shift;
	my $sa = shift;
	
	return $self->{zip}->contents("$self->{topname}/suite/$name/$sa");
}
	
1;
			
