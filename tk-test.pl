#!/usr/bin/perl -w  
use Tk;
use warnings;
use strict;
use utf8::all;

use String::Util qw( trim );
use File::Copy;

use lib '/home/b8u/projects/perl-proj/';
use DeVerbRecord;
use TestFunctions qw/sm2Quality getRecords setRecords getWindow updateRectords/;

use Data::Dumper;

sub getQuestionStream {
	my ($records, $done) = @_;
	
	my @forms = (
		[ 'Infinitive (wie ...)',    sub { shift->infinitive; }  ],
		[ 'Präsens (er/sie/es ...)', sub { shift->praesens; }    ],
		[ 'Präteritum',              sub { shift->praeteritum; } ],
		[ 'Perfekt',                 sub { shift->perfekt; }     ],
	);
	my $i = 0;

	# The argument is a given answer.
	# If there is no argument, the function returns a question.
	return sub {
		# if a records-window runs out - just exit
		my $recordsCount = scalar @$records;
		print "records count : $recordsCount\n";
		return unless ($recordsCount);

		if (scalar @_ == 1) {
			# checks the answer
			my $answer = trim(shift);
			my $right = $forms[$i]->[1]->($records->[0]);
			my $quality = TestFunctions::sm2Quality($answer, $right);

			print "answer: $answer, right: $right, quality: $quality\n";

			unless ($quality == 5) {
				$i = scalar(@forms) - 1;
			}
			if ($i == scalar(@forms) - 1) {
				my $record = shift @$records;
				$record->update($quality);
				if ($quality != 5) {
					push @$records, $record;
				}
				$i = 0;
			} else {
				++$i;
			}

			return $right;

		} else {
			# returns a question
			return $forms[$i]->[0] . ' für ' . $records->[0]->translation . ': ';
		}
	};
}

sub main {
	my $fileName = "verbs.txt";
	my $backupName = $fileName . '.backup';

	# Backup
	print "backup files: $fileName > $backupName\n";
	copy($fileName, $backupName) or die "Copy failed: $!";

	# prepare stuff
	my $res = TestFunctions::getRecords($fileName);
	my @window = TestFunctions::getWindow($res, 5);
	my @done;

	my $exit = sub {
		# finalize, save, etc
		print "finalization\n";
		TestFunctions::updateRecords($res, \@done);
		TestFunctions::setRecords($fileName, $res);

		exit 0;
	};

	# the function helps to make a stream of questions from records.
	# return true if a stream of question is not empty
	my $getNextQuestion = getQuestionStream(\@window, \@done);

	# prepare UI
	my $mw = MainWindow->new;
	my $questionText = $mw->Label(-text => $getNextQuestion->() )->pack;
	my $entry = $mw->Entry(-width => 50)->pack;
	my $log = $mw->Listbox(-width => 50, -height => 50)->pack;

	$entry->focusForce();
	$entry->bind('<Return>', sub {
			my $right = $getNextQuestion->($entry->get());
			my $logRecord =  "Right: $right, given: " . $entry->get;
			print "logRecord: $logRecord\n";
			$log->insert(0, $logRecord);
			if ($right ne trim($entry->get)) {
				$log->itemconfigure(0, -background => 'red');
			}

			my $nextQuestion = $getNextQuestion->();
			$exit->() unless ($nextQuestion);

			$entry->delete(0, length $entry->get);
			$questionText->configure(-text => $nextQuestion );
			$entry->focusForce();
		});

	# let's go
	MainLoop;

	$exit->();
}

 
main();



