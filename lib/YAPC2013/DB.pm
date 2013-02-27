package YAPC2013::DB;

use strict;
use warnings;

use parent 'Teng';

__PACKAGE__->load_plugin('Count');

sub insert {
    my ($self, $table, $args) = @_;

    warn "************************";
    # XXX TODO validation

    $args->{created_on} ||= \'NOW()';
    $self->SUPER::insert( $table, $args );
}

1;
