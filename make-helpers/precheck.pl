use strict;
use warnings;

# make some basic checks that the environment is sound
#

use 5.010_001;

foreach (qw(Carton ExtUtils::Command App::TestOnTap Hash::Merge::Simple))
{
	eval "require $_";
	die("Is $_ installed?\n$@") if $@;
}
