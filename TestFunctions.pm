package TestFunctions;

use strict;
use warnings;
use utf8::all;

our @EXPORT = qw/sm2Quality getRecords setRecords getWindow updateRectords/;

use String::Util qw( trim );
use Text::Table;
use Text::JaroWinkler qw( strcmp95 );
use List::Util qw( min max shuffle);
use DateTime;

use lib '/home/b8u/projects/perl-proj/';
use DeVerbRecord;

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

	@res = shuffle @res;

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

1;
