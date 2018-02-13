use strict;
use warnings;
use Plack::Runner;
my $runner = Plack::Runner->new();
$runner->parse_options(@ARGV);
$runner->run();
