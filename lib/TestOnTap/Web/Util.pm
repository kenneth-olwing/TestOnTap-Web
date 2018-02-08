package TestOnTap::Web::Util;

use strict;
use warnings;

our $IS_WINDOWS = $^O eq 'MSWin32';
our $PATH_SEP = $IS_WINDOWS ? '\\' : '/';
our $LIST_SEP = $IS_WINDOWS ? ';' : ':';

use Exporter qw(import);
our @EXPORT_OK =
	qw
		(
			$IS_WINDOWS
			$PATH_SEP
			$LIST_SEP
			slashify
		);

# pass in a path and ensure it contains the native form of slash vs backslash
# (or force either one)
#
sub slashify
{
	my $s = shift;
	my $fsep = shift || $PATH_SEP;

	my $dblStart = $s =~ s#^[\\/]{2}##;
	$s =~ s#[/\\]+#$fsep#g;

	return $dblStart ? "$fsep$fsep$s" : $s;
}

1;
