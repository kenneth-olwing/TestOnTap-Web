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
use JSON;

$| = 1;

exit(main());

sub main
{
	my $datadir;
	my $logdir;
	my $force;
	my $pretty;
	
	my $getopts = GetOptions
					(
						'datadir=s' => \$datadir,
						'logdir=s' => \$logdir,
						'force' => \$force,
						'pretty' => \$pretty,
					);
	
	die("usage: $0 --datadir <datadir> [--logdir <logdir>] [--force] [--pretty]\n")
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
	
	setupWithLog($logdir) if $logdir;
	
	$SIG{__WARN__} = sub { print STDERR "WARNING: $_[0]" };
	$SIG{__DIE__} = sub { print STDERR "ERROR: $_[0]"; exit(127) };

	print "=== START: " . localtime() . "\n";

	my $repeat = 1;
	while ($repeat)
	{	
		my $suitesJsonFile = "$datadir/suites.json";
		my $tsSuitesJsonFile = (stat($suitesJsonFile))[9] || 0;
		
		my @zipFiles = sort(glob("$datadir/results/*.zip"));
		my $tsNewestZipFile = 1;
		foreach my $zipFile (@zipFiles)
		{
			my $tsZipFile = (stat($zipFile))[9];
			$tsNewestZipFile = $tsZipFile if $tsZipFile > $tsNewestZipFile;
		}
	
		if ($force || $tsNewestZipFile > $tsSuitesJsonFile)
		{
			my %suite2name;
			my %name2suite;
			my %suite2objs;
			foreach my $zipFile (@zipFiles)
			{
				my $obj = TestOnTap::Web::TestResult->new($zipFile);
				if (!$obj)
				{
					warn("Not a test result, skipping: '$zipFile'\n");
					next;
				}
				print "Loaded '$zipFile'\n";
		
				my ($suiteId, $suiteName) = ($obj->getSuiteId() => $obj->getSuiteName());
				if (exists($name2suite{$suiteName}) && $name2suite{$suiteName} ne $suiteId)
				{
					warn("Reuse of suitename between $name2suite{$suiteName} and $suiteId, skipping: '$zipFile'\n");
					next;
				} 
				
				$suite2name{$suiteId} = $suiteName;
				$name2suite{$suiteName} = $suiteId;
				
				my $objs = $suite2objs{$suiteId} || [];
				push(@$objs, $obj);
				$suite2objs{$suiteId} = $objs;
			}
			
			my @jstreeData;
			foreach my $name (sort(keys(%name2suite)))
			{
				my $suiteId = $name2suite{$name};
				my $objs = $suite2objs{$suiteId};
				
				my @elapsedTimes;
				
				my @children;
				foreach my $obj (@$objs)
				{
					my $startDt = DateTime::Format::ISO8601->parse_datetime($obj->getBegin());
        			my $endDt = DateTime::Format::ISO8601->parse_datetime($obj->getEnd());
        			push(@elapsedTimes, $endDt->epoch() - $startDt->epoch());					

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
				}

				my $maxElapsed = 'N/A';
				my $minElapsed = 'N/A';
				my $avgElapsed = 'N/A';
				my $medianElapsed = 'N/A';
				if (@elapsedTimes)
				{
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
				
				my $suitedata =
					{
						id => $suiteId,
						text => $name,
						children => \@children,
						data =>
							{
								type => 'suite',
								name => $name,
								resultcount => scalar(@$objs),
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
								title => $suiteId,
								href => ''
							}
					};
				push(@jstreeData, $suitedata);
			}
			my $lock = lockFile("$suitesJsonFile.lock");
			my $p = path($suitesJsonFile);
			my $json = JSON->new()->utf8();
			$json->pretty() if $pretty;
			my $data = $json->encode(\@jstreeData);
			$p->spew_raw($data);
			$p->touch($tsNewestZipFile);
			print "$suitesJsonFile updated\n";
			unlockFile($lock);
			
			$repeat = 0 if $force;
		}
		else
		{
			print "$suitesJsonFile is up to date\n";
			$repeat = 0;
		}

		print "=== REPEAT: " . localtime() . "\n" if $repeat;
	}
		
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
	flock($fh, LOCK_EX);
	
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
