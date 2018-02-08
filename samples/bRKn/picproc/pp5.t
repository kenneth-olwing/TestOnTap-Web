use strict;
use warnings;

use Test::More;

my $numtests = int(rand(5)) + 1;

plan(tests => $numtests);

for my $testnum (1 .. $numtests)
{
	if (int(rand(100)) % 2)
	{
		pass($testnum . " (" . __FILE__ . ":" . __LINE__ . ")");
	}
	else
	{
		fail($testnum . " (" . __FILE__ . ":" . __LINE__ . ")");
	}
	sleep(int(rand(3)));
}

done_testing() if $Test::More::VERSION >= 0.88;
