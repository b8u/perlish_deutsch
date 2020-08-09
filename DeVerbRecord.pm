package DeVerbRecord;
use lib '/home/b8u/projects/perl-proj/';
use parent SM2::Record;

use strict;
use warnings;

use utf8::all;

use String::Util qw( trim );

sub new {
	my ($class, $args) = @_;
	my $self = $class->SUPER::new($args);

	$self->{translation} = $args->{verb_desc}->[0];
	$self->{infinitive}  = $args->{verb_desc}->[1];
	$self->{praesens}    = $args->{verb_desc}->[2];
	$self->{praeteritum} = $args->{verb_desc}->[3];
	$self->{perfekt}     = $args->{verb_desc}->[4];
	
	return $self;
}

sub parseArray {
	my $self = shift;

	scalar @_ >= 5 or
		die 'Not enough argumens to parse DeVerbRecord: ' . scalar(@_);
	$self->{translation} = trim(shift);
	$self->{infinitive}  = trim(shift);
	$self->{praesens}    = trim(shift);
	$self->{praeteritum} = trim(shift);
	$self->{perfekt}     = trim(shift);

	return $self->SUPER::parseArray(@_);
}

sub toArray {
	my $self = shift;
	return ( $self->translation,
             $self->infinitive,
             $self->praesens,
             $self->praeteritum,
             $self->perfekt,
			 $self->SUPER::toArray);
}

# Getters:
sub translation { return shift->{translation}; }
sub infinitive  { return shift->{infinitive};  }
sub praesens    { return shift->{praesens};    }
sub praeteritum { return shift->{praeteritum}; }
sub perfekt     { return shift->{perfekt};     }

1;

