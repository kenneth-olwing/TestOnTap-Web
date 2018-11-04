package TestOnTap::Web::Win32Util;

use strict;
use warnings;

use Win32;
use Win32::Process;

sub detachProc
{
	my @cmd = @_;
	
	$_ = qq("$_") foreach (@cmd);
	my $cmd = join(' ', @cmd); 
	my $obj;
	Win32::Process::Create
		(
			$obj,
			$^X,
			$cmd,
			0,
			DETACHED_PROCESS,
			"."
		);
		
	return $obj ? '' : Win32::FormatMessage(Win32::GetLastError());
}

1;