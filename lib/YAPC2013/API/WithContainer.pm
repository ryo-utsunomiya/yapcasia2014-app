package YAPC2013::API::WithContainer;
use Moo::Role;

has container => (
    is => 'ro',
    required => 1,
    handles => [ qw(get) ],
);

no Moo::Role;

1;
