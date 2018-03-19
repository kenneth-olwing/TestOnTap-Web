use strict;
use warnings;

# make some basic checks that the environment is sound
#

use 5.010_001;

foreach (
			qw
				(
					Carton
					ExtUtils::Command
					App::TestOnTap
					Grep::Query
					Hash::Merge::Simple
					Config::Any
				)
		)
{
	eval "require $_";
	die("Is $_ installed?\n$@") if $@;
}
