use strict;
use warnings;

for my $i (1..10)
{
	foreach my $dir (qw(
						aloha
						arbgig
						brockie
						bRKn
						fee.fie.foo
						grumsy
						hytres
						nabstar
						portyk
						vonnet
						wolla-men
						))
	{
		my $parallel = int(rand(2));
		my $jobs = $parallel ? int(rand(15)) : 1; 
		my @cmd = 
			(
				'testontap',
				'--archive',
				'--savedirectory', 'RESULTS',
				'--jobs', $jobs,
				$dir
			); 
		print "===> $i : $dir (jobs: $jobs)\n";
		system(@cmd);
	}
}
