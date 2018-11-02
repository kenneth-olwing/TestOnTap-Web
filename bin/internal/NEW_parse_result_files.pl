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
	my $force;
	
	my $getopts = GetOptions
					(
						'datadir=s' => \$datadir,
						'logdir=s' => \$logdir,
						'pretty' => \$pretty,
						'force' => \$force,
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

	my $dbJsonFile = "$datadir/db.json";
	my $tsDbJsonFile = $force ? 0 : (stat($dbJsonFile))[9] || 0;
	
	my $json = JSON->new()->utf8();
	$json->pretty() if $pretty;
	
	my $pathDbJson = path($dbJsonFile);
	my $dbJson = {}; 
	$dbJson = $json->decode($pathDbJson->slurp()) if $pathDbJson->is_file() && !$force;
	my $dbRecords = scalar(keys(%$dbJson));
	foreach my $zipFile (sort(glob("$datadir/results/*.zip")))
	{
		if ((stat($zipFile))[9] > $tsDbJsonFile)
		{
			my $obj = TestOnTap::Web::TestResult->new($zipFile);
			if (!$obj)
			{
				warn("Not a test result, skipping: '$zipFile'\n");
				next;
			}
			print "Loaded '$zipFile'\n";
			
			my $runid = $obj->getRunid();
			next if $dbJson->{$runid};
			my @tests;
			foreach my $testName (@{$obj->getTestNames()})
			{
				push(@tests, { name => $testName, has_problems => $obj->getResultForTest($testName)->{has_problems} });
			}
			$dbJson->{$runid} =
						{
							runid => $runid,
							name => $obj->getSuiteName(),
							suiteid => $obj->getSuiteId(),
							begin => $obj->getBegin(),
							end => $obj->getEnd(),
							zip => basename($obj->getFilename()),
							allpassed => $obj->getAllPassed(),
							tests => \@tests,
						};
		}
	}
	$pathDbJson->spew_raw($json->encode($dbJson)) if (scalar(keys(%$dbJson)) != $dbRecords);
	
	$tsDbJsonFile = (stat($dbJsonFile))[9] || 0;
	my $suitesJsonFile = "$datadir/suites.json";
	my $tsSuitesJsonFile = (stat($suitesJsonFile))[9] || 0;
	my $p = path($suitesJsonFile);
	if ($tsDbJsonFile > $tsSuitesJsonFile)
	{
		my $jsondata = [];

		my %suiteNames;
		foreach my $runid (keys(%{$dbJson}))
		{
			my $dbRecord = $dbJson->{$runid};
			my $suiteId = $dbRecord->{suiteid};
			my $suiteName = $dbRecord->{name};
			my $startDt = DateTime::Format::ISO8601->parse_datetime($dbRecord->{begin});
			my $recordYear = sprintf("%04d", $startDt->year());			
			my $recordMonth = sprintf("%02d", $startDt->month());			
			my $recordDay = sprintf("%02d", $startDt->day());			
			if (exists($suiteNames{$suiteName}))
			{
				if ($suiteNames{$suiteName}->{suiteid} ne $suiteId)
				{
					warn("Duplicate suitename, different suiteid: $suiteName/$suiteNames{$suiteName}->{suiteid} vs $suiteId in run $runid - skipping\n");
					next;
				}
			}
			else
			{
				$suiteNames{$suiteName} = { suiteid => $suiteId, years => {} };
			}
			my $years = $suiteNames{$suiteName}->{years};
			$years->{$recordYear} = { months => {} } unless exists($years->{$recordYear});
			my $months = $years->{$recordYear}->{months};
			$months->{$recordMonth} = { days => {} } unless exists($months->{$recordMonth});
			my $days = $months->{$recordMonth}->{days};
			$days->{$recordDay} = { records => {} } unless exists($days->{$recordDay});
			my $records = $days->{$recordDay}->{records};
			$records->{$runid} = $dbRecord;
		}

		foreach my $suiteName (keys(%suiteNames))
		{
			my $suiteId = $suiteNames{$suiteName}->{suiteid};
			
			my @yearData;
			my $years = $suiteNames{$suiteName}->{years};
			foreach my $year (keys(%$years))
			{
				my @monthData;
				my $months = $years->{$year}->{months};
				foreach my $month (keys(%$months))
				{
					my @dayData;
					my $days = $months->{$month}->{days};
					foreach my $day (keys(%$days))
					{
						my @recordData;
						my @elapsedTimes;
						my $records = $days->{$day}->{records};
						foreach my $runid (keys(%$records))
						{
							my $record = $records->{$runid};

							my @testChildren;
							foreach my $test (@{$record->{tests}})
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
										text => $test->{name},
										children => \@children, 
										data =>
											{
												type => 'test',
												name => $test->{name},
											},
										a_attr =>
											{
												href => '',
												$test->{has_problems} ? (style => 'color: red;') : (),
											}
									};
								push(@testChildren, $data);
		
							}

							push(@testChildren, { a_attr => { href => '' }, text => 'All artifacts', data => { type => 'suiteartifactstop' }});
					
							my $startDt = DateTime::Format::ISO8601->parse_datetime($record->{begin});
							my $endDt = DateTime::Format::ISO8601->parse_datetime($record->{end});
							my $elapsedTime = $endDt->epoch() - $startDt->epoch();
							push(@elapsedTimes, $elapsedTime);
							my $resultdata =
								{
									id => $record->{runid},
									text => $record->{begin},
									children => \@testChildren,
										data =>
											{
												type => 'result',
												zipfile => $record->{zip},
												timestamp => $record->{begin},
												elapsedtime => $elapsedTime,
												suitename => $record->{name},
											},
										a_attr =>
											{
												title => $record->{runid},
												href => '',
												$record->{allpassed} ? () : (style => 'color: red;'),
											}
								};
							push(@recordData, $resultdata);

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
						}

						push(@dayData,
								{
									text => $day,
									id => "$year-$month-$day-$suiteId",
									data =>
										{
											type => 'suite',
											elapsed =>
												{
													median => '0s',
													average => '0s',
													min => '0s',
													max => '0s'
												},
											resultcount => 1,
											name => "$suiteName - $year - $month - $day",
										},
									children => \@recordData,
								});
					}
					
					push(@monthData,
							{
								text => $month,
								id => "$year-$month-$suiteId",
								data =>
									{
										type => 'suite',
										elapsed =>
											{
												median => '0s',
												average => '0s',
												min => '0s',
												max => '0s'
											},
										resultcount => 1,
										name => "$suiteName - $year - $month",
									},
								children => \@dayData,
							});
				}
				
				push(@yearData,
						{
							text => $year,
							id => "$year-$suiteId",
							data =>
								{
									type => 'suite',
									elapsed =>
										{
											median => '0s',
											average => '0s',
											min => '0s',
											max => '0s'
										},
									resultcount => 1,
									name => "$suiteName - $year",
								},
							children => \@monthData,
						});
			}
			
			my %suiteData =
				(
					text => $suiteName,
					id => $suiteId,
					a_attr =>
						{
							title => $suiteId,
							href => ''
						},
					data =>
						{
							type => 'suite',
							elapsed =>
								{
									median => '0s',
									average => '0s',
									min => '0s',
									max => '0s'
								},
							resultcount => 1,
							name => $suiteName,
						},
					children => \@yearData,
				);
			
			push(@$jsondata, \%suiteData);
		}

		my $lock = lockFile("$suitesJsonFile.lock");
		$p->append({ truncate => 1 }, $json->encode($jsondata));
		print "$suitesJsonFile updated\n";
		unlockFile($lock);
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
