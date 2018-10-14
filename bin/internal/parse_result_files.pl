use strict;
use warnings;

use TestOnTap::Web::TestResult;
use TestOnTap::Web::Logger qw(applogger_init);

use DateTime::Format::ISO8601;
use Time::Duration;
use List::Util qw(max min sum);
use Path::Tiny;
use Getopt::Long;
use File::Basename;
use Fcntl qw(:flock);
use IO::Handle;
use JSON;

$| = 1;

exit(main());

sub main
{
	my $datadir;
	my $logdir;
	my $pretty;
	
	my $getopts = GetOptions
					(
						'datadir=s' => \$datadir,
						'logdir=s' => \$logdir,
						'pretty' => \$pretty,
					);
	
	die("usage: $0 --datadir <datadir> [--logdir <logdir>] [--pretty]\n")
		unless
			   $getopts
			&& $datadir && -d $datadir
			&& ($logdir ? -d $logdir : 1);
	
	my $logger = sub { chomp(@_); print join("\n", @_, ''); };
	applogger_init
		(
			{
				debug => $logger,
				info => $logger,
				warning => $logger,
				error => $logger,
			}
		);

	my $scriptlock = lockFile(($logdir || $datadir) . '/' . basename($0) . ".lock");
	
	setupWithLog($logdir) if $logdir;
	
	$SIG{__WARN__} = sub { print STDERR "WARNING: $_[0]" };
	$SIG{__DIE__} = sub { print STDERR "ERROR: $_[0]"; exit(127) };

	print "=== START: " . localtime() . "\n";

	my $suitesJsonFile = "$datadir/suites.json";
	my $tsSuitesJsonFile = (stat($suitesJsonFile))[9] || 0;
	
	my $json = JSON->new()->utf8();
	$json->pretty() if $pretty;

	my $p = path($suitesJsonFile);
	my $jsondata;
	my %existingSuiteIds;
	my %existingRunIds;
	foreach my $zipFile (sort(glob("$datadir/results/*.zip")))
	{
		if ((stat($zipFile))[9] > $tsSuitesJsonFile)
		{
			my $obj = TestOnTap::Web::TestResult->new($zipFile);
			if (!$obj)
			{
				warn("Not a test result, skipping: '$zipFile'\n");
				next;
			}
			print "Loaded '$zipFile'\n";

			my $name = $obj->getSuiteName();
			my $suiteid = $obj->getSuiteId();
			my $runid = $obj->getRunid();

			if (!$jsondata)
			{
				$jsondata = [];
				my $lock = lockFile("$suitesJsonFile.lock");
				$jsondata = $json->decode($p->slurp()) if $p->is_file();
				unlockFile($lock);
				my $sz = scalar(@$jsondata);
				for my $ndx (0..$sz - 1)
				{
					my $suitedata = $jsondata->[$ndx];
					my @elapsedTimes;
					foreach my $suitechild (@{$suitedata->{children}})
					{
						push(@elapsedTimes, $suitechild->{data}->{elapsedtime});
						$existingRunIds{$suitechild->{id}} = $suitedata->{id};
					}
					$existingSuiteIds{$suitedata->{id}} = { ndx => $ndx, testcount => scalar(@elapsedTimes), elapsedtimes => \@elapsedTimes };
				}
			}
			if (exists($existingRunIds{$runid}))
			{
				warn("Already indexed test result, skipping: '$zipFile'\n");
				next;
			}

			my $totalTestCount = 1;
			my @elapsedTimes;
			if (exists($existingSuiteIds{$suiteid}))
			{
				$totalTestCount += $existingSuiteIds{$suiteid}->{testcount};
				push(@elapsedTimes, @{$existingSuiteIds{$suiteid}->{elapsedtimes}});
			}
			
			my @children;
			my @testChildren;
			foreach my $test (@{$obj->getTestNames()})
			{
				my @children =
					(
						{
							text => 'Artifacts', 
							data =>
								{
									type => 'suiteartifacts',
								},
							a_attr =>
								{
									href => ''
								}
						}
					);
						
				my $data =
					{
						text => $test,
						children => \@children, 
						data =>
							{
								type => 'test',
								name => $test,
							},
						a_attr =>
							{
								href => '',
								$obj->getResultForTest($test)->{has_problems} ? (style => 'color: red;') : (),
							}
					};
				push(@testChildren, $data);
			}
				
			push(@testChildren, { a_attr => { href => '' }, text => 'All artifacts', data => { type => 'suiteartifactstop' }});
			
			my $startDt = DateTime::Format::ISO8601->parse_datetime($obj->getBegin());
			my $endDt = DateTime::Format::ISO8601->parse_datetime($obj->getEnd());
			my $elapsedTime = $endDt->epoch() - $startDt->epoch();
			push(@elapsedTimes, $elapsedTime);
			my $resultdata =
				{
					id => $obj->getRunid(),
					text => $obj->getBegin(),
					children => \@testChildren,
					data =>
						{
							type => 'result',
							zipfile => basename($obj->getFilename()),
							timestamp => $obj->getBegin(),
							elapsedtime => $elapsedTime,
							suitename => $name,
						},
					a_attr =>
						{
							title => $obj->getRunid(),
							href => '',
							$obj->getAllPassed() ? () : (style => 'color: red;'),
						}
				};
			push(@children, $resultdata);

			my $maxElapsed = 'N/A';
			my $minElapsed = 'N/A';
			my $avgElapsed = 'N/A';
			my $medianElapsed = 'N/A';
			$maxElapsed = concise(duration(max(@elapsedTimes)));
			$minElapsed = concise(duration(min(@elapsedTimes)));
			$avgElapsed = concise(duration(int(sum(@elapsedTimes) / scalar(@elapsedTimes))));
			if (@elapsedTimes == 1)
			{
				$medianElapsed = $elapsedTimes[0];
			}
			elsif (@elapsedTimes % 2 == 0)
			{
				my $half = @elapsedTimes/2;
				$medianElapsed = ($elapsedTimes[$half - 1] + $elapsedTimes[$half])/2;
			}
			else
			{
				$medianElapsed = $elapsedTimes[int(@elapsedTimes/2)];
			}
			$medianElapsed = concise(duration($medianElapsed));
		
			my $suitedata =
				{
					id => $suiteid,
					text => $name,
					children => \@children,
					data =>
						{
							type => 'suite',
							name => $name,
							resultcount => $totalTestCount,
							elapsed =>
								{
									average => $avgElapsed,
									max => $maxElapsed,
									min => $minElapsed,
									median => $medianElapsed
								}
						},
					a_attr =>
						{
							title => $suiteid,
							href => ''
						}
				};
	
			if (exists($existingSuiteIds{$suiteid}))
			{
				my $ndx = $existingSuiteIds{$suiteid}->{ndx};
				push(@{$suitedata->{children}}, @{$jsondata->[$ndx]->{children}});
				$jsondata->[$ndx] = $suitedata;
				$existingSuiteIds{$suiteid} = { ndx => $ndx, testcount => $suitedata->{data}->{resultcount}, elapsedtimes => \@elapsedTimes }; 
			}
			else
			{
				push(@$jsondata, $suitedata);
				$existingSuiteIds{$suiteid} = { ndx => scalar(@$jsondata) - 1, testcount => 1, elapsedtimes => [ $elapsedTime ] }; 
			}
			$existingRunIds{$runid} = $suiteid;
		}

		if ($jsondata && @$jsondata)
		{
			my $lock = lockFile("$suitesJsonFile.lock");
			$p->append({ truncate => 1 }, $json->encode($jsondata));
			print "$suitesJsonFile updated\n";
			unlockFile($lock);
		}
	}

	unlockFile($scriptlock);

	return 0;
}

END
{
	print "=== END: " . localtime() . "\n";
}

##

sub setupWithLog
{
	my $logdir = shift;

	my $logfile = basename($0);
	$logfile =~ s/\.[^.]+$/.log/;
	$logfile = "$logdir/$logfile";

#	print "Stdout/err will be redirected to '$logfile'\n";
		
	open(my $fh, '>>', $logfile) or die("Failed to aopen '$logfile': $!\n");
	$fh->autoflush(1);
	
	*STDOUT = *STDERR = $fh;
}

sub lockFile
{
	my $fn = shift;

	open(my $fh, '>', $fn) or die("Failed to ropen '$fn': $!\n");
	flock($fh, LOCK_EX);

	return $fh;
}

sub unlockFile
{
	my $fh = shift;
	
	flock($fh, LOCK_UN);
	close($fh);
}
