use strict;
use warnings;

use ExtUtils::Command;

foreach my $p (@ARGV)
{
	if (-e $p)
	{
		print "Deleting '$p'...\n";
		rm_rf($p);
		die("Failed to delete '$p': $!") if -e $p;
	}
}
