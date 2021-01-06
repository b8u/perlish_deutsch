#!env perl

use Test2::Tools::Basic;
use Test2::Tools::Compare;

use DateTime;
use DateTime::Format::RFC3339;

use lib '../';
use SM2::Record;


my $tdt = DateTime->new(
	year      => 1964,
	month     => 10,
	day       => 16,
	hour      => 16,
	minute    => 12,
	time_zone => 'Asia/Taipei'
);

my $stdt = DateTime::Format::RFC3339->format_datetime($tdt);


{ # defaults
	my $record = SM2::Record->new;
	ok( $record->ef == 2.5, 'checking default ef' );
	ok( $record->repetition == 1, 'checking default repetition count' );
	ok( DateTime->compare($record->nextRepetition, DateTime->now) == 0,
		'checking default next date repetition' );
}

{ # custom constructor values
	# use DateTime
	my $r1 = SM2::Record->new({
		ef => 1,
		repetition => 8,
		nextRepetition => $tdt
	});

	ok( $r1->ef == 1.0, 'checking custom ef' );
	ok( $r1->repetition == 8, 'checking castom repetition count' );
	ok( DateTime->compare($r1->nextRepetition, $tdt) == 0,
		'checking custom next date repetition' );


	# use serialized DateTime
	my $r2 = SM2::Record->new({
		ef => 1,
		repetition => 8,
		nextRepetition => $tdt
	});

	ok( $r2->ef == 1.0, 'checking custom ef' );
	ok( $r2->repetition == 8, 'checking castom repetition count' );
	ok( DateTime->compare($r2->nextRepetition, $tdt) == 0,
		'checking custom next date repetition' );
}

{ # intervals

	ok( SM2::Record::interval(1, 2.5) == 1 );
	ok( SM2::Record::interval(1, 1.5) == 1 );
	ok( SM2::Record::interval(1, 0.0) == 1 );
	ok( SM2::Record::interval(1, 9.0) == 1 );

	ok( SM2::Record::interval(2, 2.5) == 6 );
	ok( SM2::Record::interval(2, 1.5) == 6 );
	ok( SM2::Record::interval(2, 0.0) == 6 );
	ok( SM2::Record::interval(2, 9.0) == 6 );


	ok( SM2::Record::interval(3, 1.0) == 6 );
	ok( SM2::Record::interval(3, 2.0) == 12 );
}

{
	my $rGood = SM2::Record->new;
	my $rBad = SM2::Record->new;

	$rGood->update(5);
	$rBad->update(0);

	ok( $rGood->ef == 2.6 );
	ok( $rBad->ef == 1.7 );

}

{
	my @given = SM2::Record->new({ nextRepetition => $tdt })->toArray;
	is( \@given, [ 2.5, 1, $stdt ] );

	my $given = SM2::Record->new({ nextRepetition => $tdt })->toString;
	ok( $given eq "2.5 | 1 | $stdt" );
}

done_testing;
