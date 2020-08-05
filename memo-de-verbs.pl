#!env perl

use warnings;
use strict;
use utf8::all;

use String::Util qw( trim );
use Text::Table;
use Text::JaroWinkler qw( strcmp95 );
use List::Util qw( min max );

use DateTime;
use DateTime::Format::RFC3339;

use Data::Dumper;


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

sub sm2EF {
	my ($ef, $q) = @_;
	return $ef - 0.8 + 0.28 * $q - 0.02 * $q * $q;
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
		  ];
=cut

sub sm2AppendTechData {
	my $data = shift;
	die "Invalid data record: " . scalar(@$data) . ' | ' . join(', ', @$data) if (scalar @$data < 5);
	splice @$data, 5;

	my @date = localtime();

	$data->[5] = DateTime::Format::RFC3339->format_datetime(DateTime->now);
	$data->[6] = 2.5;
	$data->[7] = 1;
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

	# the file has the following structure:
	# translation|\s+verb form 1|\s+verb form 2|\s+verb form 3|\s+tech data
	
	my @res;
	while (<$file>) {
		chomp;
		my @data = grep(s/^\s*|\s*$//g, split /\|/);

		if (scalar @data == 5) {
			sm2AppendTechData(\@data);
		} elsif (scalar @data > 5) {
			$data[5] = DateTime::Format::RFC3339->parse_datetime($data[5]);
		}
		push @res, \@data;
	}

	close $file;

	return \@res;
}


sub setRecords {
	my ($filePath, $data) = @_;

	open(my $file, '>', $filePath) or die $!;

	my $table = Text::Table->new();
	my @tbData = @$data;
	foreach my $v (@tbData) {
		my @raw = grep(s/^\s*|\s*$//g, split "\f", join "\f|\f", @$v);
		$v = \@raw;
	}
	$table->load(@tbData);

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

sub verbAsk {
	my $record = shift;
	print "Infinitive für $record->[0]: ";
	$_ = <STDIN>;
	chomp;
	if ($_ eq $record->[1]) {
		print "ok\n";
	} else {
		print "falsch: $record->[1]\n"
	}
	
	print "Präsens für $record->[0]: ";
	$_ = <STDIN>;
	chomp;
	if ($_  eq $record->[2]) {
		print "ok\n";
	} else {
		print "falsch: $record->[2]\n"
	}
		    
	print "Präteritum für $record->[0]: ";
	$_ = <STDIN>;
	chomp;
	if ($_ eq $record->[3]) {
		print "ok\n";
	} else {
		print "falsch: $record->[3]\n"
	}
		    
	print "Perfekt für $record->[0]: ";
	$_ = <STDIN>;
	chomp;
	if ($_ eq $record->[4]) {
		print "ok\n";
	} else {
		print "falsch: $record->[4]\n"
	}

	return 1;
}

sub main {
	my $fileName = "verbs.txt";
	my $res = getRecords($fileName);
	my @window = getWindow($res, 5);
	my @done;
	while (scalar @window) {
		my $top = shift @window;
		unless (verbAsk($top)) {
			push @window, $top;
		} else {
			push @done, $top;
		}
	}
	updateRecords($res, \@done);
	setRecords($fileName, $res);
}

main();




1;
