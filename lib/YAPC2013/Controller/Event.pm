package YAPC2013::Controller::Event;
use Mojo::Base 'YAPC2013::Controller::CRUD';

sub index { $_[0]->redirect_to("/2013/event/list") }

sub input {
    my $self = shift;
    my $member = $self->assert_email or return;

    $self->SUEPR::input(@_);
}

1;