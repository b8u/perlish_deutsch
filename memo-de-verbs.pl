#!env perl

use warnings;
use strict;
use utf8::all;

# use String::Util qw( trim );
use Text::Table;
#use Text::JaroWinkler qw( strcmp95 );
#use List::Util qw( min max );

use DateTime;

use Data::Dumper;

use lib '/home/b8u/projects/perl-proj/';
use DeVerbRecord;


#
# EF' - new value of the E-Factor
# 	EF':=EF-0.8+0.28*q-0.02*q*q
#
# EF - old value of the E-Factor
#
# q - quality of the response
# 	5 - perfect response
# 	4 - correct response after a hesitation
# 	3 - correct response recalled with serious difficulty
# 	2 - incorrect response; where the correct one seemed easy to recall
# 	1 - incorrect response; the correct one remembered
# 	0 - complete blackout.
#
# f - function used in calculating EF'.
#


my $nextUsageIdx = 5;
my $efIdx = 6;
my $repIntervalIdx = 7;
my $repetitionIdx = 8;

sub sm2EF {
	my ($ef, $q) = @_;
	return max($ef - 0.8 + 0.28 * $q - 0.02 * $q * $q, 1.3);
}

sub sm2Quality {
	my ($right, $given) = @_;
	my $q = strcmp95($right, $given, max(length $right, length $given));
	$q *= 5.0;
	return int($q);
}

sub sm2InterRepetitionInterval {
	my ($lastInterval, $ef) = @_;

	return 1 if ($lastInterval == 1);
	return 6 if ($lastInterval == 2);

	return sm2InterRepetitionInterval($lastInterval - 1) * $ef;
}


=pod
=head2 Verb test record
	$record = [
		    # Users data:
		    'Translation',               # 1  0
		    'Infinitive',                # 2  1
		    'Präsens',                   # 3  2
		    'Präteritum',                # 4  3
		    'Perfekt',                   # 5  4
                                                       
		    # Tech-data:                       
		    'Next usage',                # 6  5
		    'EF',                        # 7  6
		    'Inter-repetition interval', # 8  7
			'Repetition (count)',        # 9  8
		  ];
=cut

sub sm2AppendTechData {
	my $data = shift;
	die "Invalid data record: " . scalar(@$data) . ' | ' . join(', ', @$data) if (scalar @$data < 5);
	#splice @$data, 5;

	my @date = localtime();

	if ($data->[$nextUsageIdx]) {
		my $type = ref($data->[$nextUsageIdx]) || 'SCALAR';
		if ($type eq 'SCALAR') {
			print $data->[$nextUsageIdx];
			$data->[$nextUsageIdx] = DateTime::Format::RFC3339->parse_datetime($data->[$nextUsageIdx]);
		}
		$type = ref($data->[$nextUsageIdx]) || 'SCALAR';
		$type eq 'DateTime' or die "next usage type: " . $type;
	} else {
		$data->[$nextUsageIdx] = DateTime::Format::RFC3339->format_datetime(DateTime->now) 
	}

	$data->[$efIdx         ] = 2.5 unless ($data->[$efIdx         ]);
	$data->[$repIntervalIdx] = 1   unless ($data->[$repIntervalIdx]);
	$data->[$repetitionIdx ] = 1   unless ($data->[$repetitionIdx ]);
}


sub cmpRecords {
	my ($a, $b) = @_;
	# repetition is more important than learn something new
	my $res = $b->[7] <=> $a->[7];
	$res = $a->[6] <=> $b->[6] if ($res == 0);
	$res = DateTime->compare($a->[5], $b->[5]) if ($res == 0);
	return $res;
}


sub getRecords {
	my $filePath = shift;

	open(my $file, '<', $filePath) or die $!;

	my @res;
	while (<$file>) {
		chomp;
		my @data = grep(s/^\s*|\s*$//g, split /\|/);
		my $record = DeVerbRecord->new;
		$record->parseArray(@data);
		push @res, $record;
	}

	close $file;

	return \@res;
}


sub setRecords {
	my ($filePath, $data) = @_;

	open(my $file, '>', $filePath) or die $!;

	my $table = Text::Table->new();
	my @tbData = ();
	foreach my $v (@$data) {
		my @recordArray = split "\f", join("\f|\f", $v->toArray);
		push @tbData, \@recordArray;
	}
	$table->load(@tbData);
	print $table;

	print $file $table->table;
	close $file

}

sub getWindow {
	my ($records, $limit) = @_;
	my $now = DateTime->now;
	my @window = grep { DateTime->compare($now, $_->[5]) >= 0 } @$records;
	@window = sort { cmpRecords($a, $b) } @window;
	return splice @window, 0, $limit;
}

sub updateRecords {
	my ($records, $window) = @_;
	foreach my $record (@$records)  {
		foreach my $winRecord (@$window) {
			if ($record->[0] eq $winRecord->[0] and 
			    $record->[1] eq $winRecord->[1] and 
			    $record->[2] eq $winRecord->[2] and 
			    $record->[3] eq $winRecord->[3] and 
			    $record->[4] eq $winRecord->[4]) {
				$record->[5] = $winRecord->[5];
				$record->[6] = $winRecord->[6];
				$record->[7] = $winRecord->[7];
		    }
					
		}
	}
}

sub judge {
	my ($answer, $idx, $record) = @_;
	my $quality = sm2Quality($answer, $record->[$idx]);

	# counts the first answer:
	my $now = DateTime->now;
	if (DateTime->compare($now, $record->[$nextUsageIdx]) >= 0) {

		print "update\n";

		my $interval = sm2InterRepetitionInterval($record->[$repetitionIdx]);
		$record->[$repIntervalIdx] = $interval;
		my $nextTime = DateTime->now;
		$nextTime->add( days => $interval );
		$record->[$nextUsageIdx] = $nextTime;
		$record->[$efIdx] = sm2EF($record->[$efIdx], $quality);
	}

	# repeat until we get the right result
	return $quality == 5; 
}

sub verbAsk {
	my $record = shift;
	my @forms = (
		[ 'Infinitive', 1 ],
		[ 'Präsens', 2 ],
		[ 'Präteritum', 3 ],
		[ 'Perfekt', 4 ],
	);

	for my $form (@forms) {
		print $form->[0] . " für $record->[0]: ";
		$_ = <STDIN>;
		chomp;
		my $right = $record->[$form->[1]];
		if (judge($_, int($form->[1]), $record)) {
			print "ok\n";
		} else {
			print "falsch: $right\n";
			return 0;
		}
	}

	return 1;
}

sub main {
	my $fileName = "verbs.txt";
	my $res = getRecords($fileName);

	# for my $record ($res) {
	# 	print $record->toString, "\n";
	# }

	# my @window = getWindow($res, 5);
	# my @done;
	# while (scalar @window) {
	# 	my $top = shift @window;
	# 	unless (verbAsk($top)) {
	# 		push @window, $top;
	# 	} else {
	# 		push @done, $top;
	# 	}
	# }
	# updateRecords($res, \@done);
	setRecords($fileName, $res);

}

main();




1;
