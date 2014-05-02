package YAPCApp::API::Talk;
use Moo;

with 'YAPCApp::API::WithDBI';

around create => sub {
    my ($next, $self, $args) = @_;

    $args->{id} ||= lc($self->get('UUID')->create_str);
    $self->$next($args);
};

no Moo;

1;

