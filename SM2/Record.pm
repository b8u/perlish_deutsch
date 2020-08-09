package SM2::Record;

use strict;
use warnings;

use utf8::all;

use DateTime;
use DateTime::Format::RFC3339;
use Text::JaroWinkler qw( strcmp95 );
use List::Util qw( min max );

=pod
This is a base class for various tests. It contains only technical data
to select a learning window.
=cut

sub new {
	my ($class, $args) = @_;
	if (not defined $args) {
		$args = {};
	}

	$args->{ef            } = 2.5           unless($args->{ef});
	$args->{repetition    } = 1             unless($args->{repetition});
	$args->{nextRepetition} = DateTime->now unless($args->{nextRepetition});

	my $self = bless {
		ef             => $args->{ef            },
		repetition     => $args->{repetition    },
		nextRepetition => $args->{nextRepetition},
	}, $class;
}

sub update { 
	my ($self, $q) = @_;

	my $now = DateTime->now;
	# just the first update counts
	return if (DateTime->compare($self->nextRepetition, $now) > 0);

	$self->{ef} = max($self->{ef} - 0.8 + 0.28 * $q - 0.02 * $q * $q, 1.3);
	$self->{repetition} += 1;
	
	$now->add( days => interval($self->{repetition}) );
	$self->{nextRepetition} = $now;
}

sub parseArray {
	my $self = shift;

	return unless (scalar @_);
	my $nextUsage = shift;
	if (ref($nextUsage eq 'DateTime')) {
		$self->{nextRepetition} = $nextUsage;
	} else {
		$self->{nextRepetition} = DateTime::Format::RFC3339->parse_datetime($nextUsage);
	}

	return unless (scalar @_);
	$self->{ef} = shift;

	return unless (scalar @_);
	$self->{repetition} = shift;

	return 1;
}

sub toArray {
	my $self = shift;
	return ( $self->ef, $self->repetition, $self->nextRepetitionString );
}

sub toString {
	join(' | ', shift->toArray);
}

# Getters:
sub ef             { shift->{ef};             }
sub repetition     { shift->{repetition};     }
sub nextRepetition { shift->{nextRepetition}; }
sub nextRepetitionString { DateTime::Format::RFC3339->format_datetime(shift->nextRepetition); }

# Static functions:
sub interval {
	my ($repetition, $ef) = @_;

	return 1 if ($repetition == 1);
	return 6 if ($repetition == 2);

	return interval($repetition - 1) * $ef;
}

=pod
 q - quality of the response
 	5 - perfect response
 	4 - correct response after a hesitation
 	3 - correct response recalled with serious difficulty
 	2 - incorrect response; where the correct one seemed easy to recall
 	1 - incorrect response; the correct one remembered
 	0 - complete blackout.
=cut

sub quality {
	my ($right, $given) = @_;
	my $q = strcmp95($right, $given, max(length $right, length $given));
	$q *= 5.0;
	return int($q);
}

1;
