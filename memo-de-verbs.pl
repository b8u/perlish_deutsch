#!env perl

use warnings;
use strict;
use utf8::all;

use File::Copy;
use Data::Dumper;

use lib '/home/b8u/projects/perl-proj/';
use DeVerbRecord;
use TestFunctions qw/sm2Quality getRecords setRecords getWindow updateRectords/;

sub verbAsk {
	my $record = shift;
	my @forms = (
		[ 'Infinitive (wie ...)', $record->infinitive  ],
		[ 'Präsens (er/sie/es ...)',    $record->praesens    ],
		[ 'Präteritum', $record->praeteritum ],
		[ 'Perfekt',    $record->perfekt     ],
	);

	my $quality = 0;
	my $i = 1;
	for my $form (@forms) {
		print $form->[0] . ' für ' . $record->translation . ': ';
		$_ = <STDIN>;
		chomp;
		my $right = $form->[1];
		$quality = TestFunctions::sm2Quality($_, $right);
		if ($quality == 5) {
			print "ok\n";
		} else {
			print "falsch: $right\n";
			$quality = 0 unless ($i == scalar @forms);
			last;
		}

		++$i;
	}

	$record->update($quality);

	return $quality == 5;
}

sub main {
	my $fileName = "verbs.txt";
	my $backupName = $fileName . '.backup';

	# Backup
	print "backup files: $fileName > $backupName\n";
	copy($fileName, $backupName) or die "Copy failed: $!";


	my $res = TestFunctions::getRecords($fileName);
	my @window = TestFunctions::getWindow($res, 5);
	my @done;
	while (scalar @window) {
		my $top = shift @window;
		unless (verbAsk($top)) {
			push @window, $top;
		} else {
			push @done, $top;
		}
	}
	TestFunctions::updateRecords($res, \@done);
	TestFunctions::setRecords($fileName, $res);
}

main();




1;
