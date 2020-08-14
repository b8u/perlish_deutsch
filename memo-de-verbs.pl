#!env perl

use warnings;
use strict;
use utf8::all;

use String::Util qw( trim );
use Text::Table;
use Text::JaroWinkler qw( strcmp95 );
use List::Util qw( min max );

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

sub sm2Quality {
	my ($right, $given) = @_;
	my $q = strcmp95($right, $given, max(length $right, length $given));
	$q *= 5.0;
	return int($q);
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
	print $file $table->table;
	close $file
}

sub getWindow {
	my ($records, $limit) = @_;
	my $now = DateTime->now;
	my @window = grep { DateTime->compare($now, $_->nextRepetition) >= 0 } @$records;
	@window = sort {
		# repetition is more important than learn something new
		my $res = $b->repetition <=> $a->repetition;

		if (not $res) {
			$res = $a->ef <=> $b->ef;
		}

		if (not $res) {
			$res = DateTime->compare($a->nextRepetition, $b->nextRepetition);
		}

		return $res;
	} @window;
	return splice @window, 0, $limit;
}

sub updateRecords {
	my ($records, $window) = @_;
	foreach my $record (@$records)  {
		foreach my $winRecord (@$window) {
			if ($record->infinitive  eq $winRecord->infinitive  and 
			    $record->perfekt     eq $winRecord->perfekt     and 
			    $record->praesens    eq $winRecord->praesens    and 
			    $record->praeteritum eq $winRecord->praeteritum and 
			    $record->translation eq $winRecord->translation) {
				$record->ef($winRecord->ef);
				$record->repetition($winRecord->repetition);
				$record->nextRepetition($winRecord->nextRepetition);
		    }
		}
	}
}

sub verbAsk {
	my $record = shift;
	my @forms = (
		[ 'Infinitive', $record->infinitive  ],
		[ 'Präsens',    $record->praesens    ],
		[ 'Präteritum', $record->praeteritum ],
		[ 'Perfekt',    $record->perfekt     ],
	);

	my $quality = 0;
	for my $form (@forms) {
		print $form->[0] . ' für ' . $record->translation . ': ';
		$_ = <STDIN>;
		chomp;
		my $right = $form->[1];
		$quality = sm2Quality($_, $right);
		if ($quality == 5) {
			print "ok\n";
		} else {
			print "falsch: $right\n";
			last;
		}
	}

	$record->update($quality);

	return $quality == 5;
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
