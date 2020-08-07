package DeVerbRecord;
use parent 'SM2::Record';

use strict;
use warnings;

use utf8::all;

sub new {
	my ($class, $args) = @_;
	my $self = SUPER::new($args);

	$self->{translation} = $args->{verb_desc}->[0];
	$self->{infinitive}  = $args->{verb_desc}->[1];
	$self->{praesens}    = $args->{verb_desc}->[2];
	$self->{praeteritum} = $args->{verb_desc}->[3];
	$self->{perfekt}     = $args->{verb_desc}->[4];

	bless $self, $class;
}

sub parse_array {
	my $self = shift;

	return 0 if (scalar @_ < 5);
	$self->{translation} = shift;
	$self->{infinitive} = shift;
	$self->{praesens} = shift;
	$self->{praeteritum} = shift;
	$self->{perfekt} = shift;

	return SUPER::parse_array(@_);
}

# Getters:
sub translation { return shift->{translation}; }
sub infinitive  { return shift->{infinitive};  }
sub praesens    { return shift->{praesens};    }
sub praeteritum { return shift->{praeteritum}; }
sub perfekt     { return shift->{perfekt};     }

1;

