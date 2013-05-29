package YAPC2013::Controller::IndividualSponsors;
use Mojo::Base 'YAPC2013::Controller::CRUD';
use YAPC2013::Constants;

sub index {
    my $self = shift;
    my $json = $self->get('JSON');
    open my $fp, "<", "var/individual_sponsors.json";
    my $data = $json->decode(<$fp>);
    close $fp;

    $self->render( sponsors => $data );
}

1;
