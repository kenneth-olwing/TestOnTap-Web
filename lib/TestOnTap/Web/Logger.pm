package TestOnTap::Web::Logger;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = 
	qw
		(
			appdebug
			appinfo
			appwarning
			apperror
		);
our @EXPORT_OK =
	qw
		(
			applogger_init
		);

my $subs;

sub applogger_init
{
	$subs = shift;
}

sub appdebug
{
	$subs->{debug}->(@_);
}

sub appinfo
{
	$subs->{info}->(@_);
}

sub appwarning
{
	$subs->{warning}->(@_);
}

sub apperror
{
	$subs->{error}->(@_);
}

1;
