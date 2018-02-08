package TestOnTap::Web::API::V1::Routes;

use strict;
use warnings;

use TestOnTap::Web::TestResult;
use TestOnTap::Web::Config;

use File::Basename;
use HTML::Entities;
use Fcntl qw(:flock);
use Data::Dump qw(pp);
use DateTime::Format::ISO8601;
use Time::Duration;
use URI;

use Dancer2 appname => 'TestOnTap-Web';

prefix '/api/v1';

post '/upload' => sub
	{
		my $uploads = upload('testresult');

		my $jsonAnswer = to_json(TestOnTap::Web::TestResult->validateUpload($uploads));

		debug(pp($jsonAnswer));
		
		return $jsonAnswer;
	};

post '/render/:type' => sub
	{
		my $data = from_json(request->body);
		my $type = route_parameters->get('type');

		if ($type eq 'result')
		{
			my $tr = TestOnTap::Web::TestResult->new("$appconfig->{datadir}/results/$data->{zipfile}");

			my $overview =
				{
					'Host' => $tr->getHost() . '/' . $tr->getPlatform() . ' (' . join(', ', @{$tr->getUname()}) . ')',
					'User' => $tr->getUser(),
				};

			my $jobs = $tr->getJobs();
			
			$overview->{'Parallelized'} = $jobs > 1 ? "Yes ($jobs)" : "No";

			my $startDt = DateTime::Format::ISO8601->parse_datetime($tr->getBegin());
			my $endDt = DateTime::Format::ISO8601->parse_datetime($tr->getEnd());
			$overview->{'Ran between'} = localtime($startDt->epoch()) . " - " . localtime($endDt->epoch()) . ' (' . concise(duration($endDt->epoch() - $startDt->epoch())) . ')';

			my $testCount = $tr->getTestCount();
			my ($microTestCount, $pass, $fail) = $tr->getMicroTestCount();
			my $passPct = $microTestCount ? int(($pass / $microTestCount) * 10000) / 100 : 100;
			my $failPct = 100 - $passPct;
			$overview->{'Tests/Microtests'} = "$testCount/$microTestCount (Pass: $pass/$passPct%, Fail: $fail/$failPct%)";
			
			$data->{overview} = $overview;
			$data->{env} = $tr->getEnv();
		}
		elsif ($type eq 'test')
		{
			my $tr = TestOnTap::Web::TestResult->new("$appconfig->{datadir}/results/$data->{zipfile}");
			
			my $result = $tr->getResultForTest($data->{name});
			my $overview = {};
			
			my $startDt = DateTime::Format::ISO8601->parse_datetime($result->{start_time});
			my $endDt = DateTime::Format::ISO8601->parse_datetime($result->{end_time});
			$overview->{'Ran between'} = localtime($startDt->epoch()) . " - " . localtime($endDt->epoch()) . ' (' . concise(duration($endDt->epoch() - $startDt->epoch())) . ')';
			$data->{overview} = $overview;
			$data->{test} = $result;
			
			my @tap;
			foreach my $line (split(/\r?\n/, $tr->getTapForTest($data->{name})))
			{
				push(@tap, $line) unless $line =~ /^\s*$/;
			}
			
			$_ = encode_entities($_) foreach (@tap);
			
			foreach my $failnum (@{$result->{failed}})
			{
				for my $i (0 .. $#tap)
				{
					next unless $tap[$i] =~ /^not ok $failnum /;
					
					my $l = $failnum + 1;
					for my $j ($i .. $#tap)
					{
						last if $tap[$j] =~ /^(not )?ok $l /;
						$tap[$j] = qq(<span class="taptext taperror">$tap[$j]</span>);
					}
				}
			}
			
			foreach (@tap)
			{
				$_ = qq(<span class="taptext tapok">$_</span>) unless $_ =~ /^<span /;
			}

			$data->{tap} = \@tap;
		}
		elsif ($type eq 'suiteartifacts')
		{
			my $tr = TestOnTap::Web::TestResult->new("$appconfig->{datadir}/results/$data->{zipfile}");
			my $artifacts = $tr->getSuiteArtifactNamesForTest($data->{name});
			
			my %tree;
			foreach my $line (@$artifacts)
			{
				my $loc = \%tree;
				foreach my $part (split(m#/#, $line), undef)
				{
					if (defined($part))
					{
						$loc->{$part} = {} unless exists($loc->{$part});
						$loc = $loc->{$part}; 
					}
				}
			}

			$data->{htmlized} = htmlize(\%tree, $data);
		}

		template(${type}, $data);
	};
	
get '/suites' => sub
	{
		my $file = "$appconfig->{datadir}/suites.json";
		var needlock => "$file.lock"; 
		send_file($file, system_path => 1);
	};

hook before_file_render => sub
	{
		my $path = shift;

		my $needlock = var 'needlock';
		if ($needlock)
		{
			debug("Locking '$needlock'");
			open (my $fh, '>', $needlock) or die("Failed to open '$needlock': $!\n");
			flock($fh, LOCK_EX);
			var needlock_fh => $fh;
		}
	};

hook after_file_render => sub
	{
		my $response = shift;
		my $needlock = var 'needlock';
		if ($needlock)
		{
			debug("Unlocking '$needlock'");
			my $fh = var 'needlock_fh'; 
			flock($fh, LOCK_UN);
			close($fh);
		}
	};

sub htmlize
{
	my $root = shift;
	my $data = shift;
	my $path = shift || '';
	
	$path .= '/' if $path;
	
	my @items = sort(keys(%$root));

	my $list = '';	
	if (@items)
	{
		$list .= qq(<ul>\n);
	
		foreach my $item (@items)
		{
			my $xitem = encode_entities($item);
			$list .= qq(<li>\n);
			my $href = '';
			my $class = 'xitem-dir';
			if (!keys(%{$root->{$item}}))
			{
				my $uri = URI->new("/download/suiteartifact");
				$uri->query_form(zipfile => $data->{zipfile}, test => $data->{name}, sa => "$path$item");
				$href = $uri->as_string();
				$class = 'xitem-file';
			}
			$list .= qq(<a href="$href" class="$class">$xitem</a>\n);
			$list .= htmlize($root->{$item}, $data, "$path$item") if (keys(%{$root->{$item}}));
			$list .= qq(</li>\n);
		} 
	
		$list .= qq(</ul>\n);
	}
	
	return $list;
}	
true;
