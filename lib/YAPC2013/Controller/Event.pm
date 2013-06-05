package YAPC2013::Controller::Event;
use Mojo::Base 'YAPC2013::Controller::CRUD';

sub index { $_[0]->redirect_to("/2013/event/list") }

sub input {
    my $self = shift;
    my $member = $self->assert_email or return;

    $self->SUPER::input(@_);
}

sub commit {
    my $self = shift;
    my $member = $self->assert_email or return;
    my $data = $self->load_from_subsession();
    if (! $data) {
        $self->subsession_not_found();
        return;
    }

    if (! $data->{is_edit}) {
        $data->{member_id} = $member->{id};
    }
    local $data->{start_on_date};
    local $data->{start_on_time};
    $data->{start_on} = sprintf "%s %s",
        delete $data->{start_on_date},
        delete $data->{start_on_time}
    ;
    $self->SUPER::commit();
}

1;