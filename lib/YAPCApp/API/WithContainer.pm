package YAPCApp::API::WithContainer;
use Moo::Role;

has container => (
    is => 'ro',
    required => 1,
    handles => [ qw(get) ],
);

no Moo::Role;

1;
