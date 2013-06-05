package YAPC2013::API::Event;
use Moo;

with 'YAPC2013::API::WithDBI';

around create => sub {
    my ($next, $self, $args) = @_;

    $args->{id} ||= lc($self->get('UUID')->create_str);
    $self->$next($args);
};

no Moo;

1;
