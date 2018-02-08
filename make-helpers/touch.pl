use strict;
use warnings;

foreach my $p (@ARGV)
{
	if (!-e $p)
	{
		open(my $fh, '>', $p) or die("Failed to create '$p': $!");
		close($fh);
	}
	utime(undef, undef, $p) or die("Failed to set mtime on '$p': $!");
}