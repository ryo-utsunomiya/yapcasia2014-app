package YAPCApp::Controller::Event;
use Mojo::Base 'YAPCApp::Controller::CRUD';
use YAPCApp::Constants;

sub index { $_[0]->redirect_to("/2014/event/list") }

sub show {
    my $self = shift;
    $self->SUPER::show();
    if (my $event = $self->stash->{event}) {
        my $organizer = $self->get('API::Member')->lookup($event->{member_id});
        if (my $member = $self->get_member) {
            if ($event->{member_id} eq $member->{id}) {
                $self->stash( owner => 1 );
            }
            $self->stash( member => $member );
        }
        $self->stash(organizer => $organizer);

        if( my $venue_id = $event->{venue_id} ){
            $event->{venue} = VENUE_ID2NAME->{$venue_id};
        }
    }
}

sub list {
    my $self = shift;

    my $event_api = $self->get('API::Event');
    my $member_api = $self->get('API::Member');

    my $official_events = $event_api->search(
        { status => 1, is_official => 1 },
        { order_by => "start_on ASC, created_on ASC" },
    );

    my $unofficial_events = $event_api->search(
        { status => 1, is_official => 0 },
        { order_by => "start_on ASC, created_on ASC" },
    );

    foreach my $event ( ( @$official_events, @$unofficial_events ) ){
        $event->{organizer} = $member_api->lookup( $event->{member_id} );
    }

    $self->stash(
        official_events     => $official_events,
        unofficial_events   => $unofficial_events,
    );
}

sub input {
    my $self = shift;
    my $member = $self->assert_logged_in or return;

    $self->stash(venues => VENUES );
    $self->SUPER::input(@_);
}

sub edit {
    my $self = shift;
    my $member = $self->assert_logged_in or return;

    my $id = $self->param('object_id');
    my $object = $self->load_object( $id );
    if (! $object) {
        $self->render_not_found();
        return;
    }

    if ($member->{id} ne $object->{member_id} && !$member->{is_admin}) {
        $self->render("No auth");
        $self->rendered(403);
        return;
    }

    $self->SUPER::edit();

    my ($date, $time) =
        ($object->{start_on} =~ /^(\d+-\d+-\d+) (\d+:\d+)/);

    $self->stash->{fif}->{start_on_date} = $date;
    if ($time !~ /^00:00:00$/) {
        $self->stash->{fif}->{start_on_time} = $time;
    }
    $self->stash(venues => VENUES );
}

sub preview {
    my $self = shift;

    $self->SUPER::preview();
    $self->stash(venue_id2name => VENUE_ID2NAME );
}

sub commit {
    my $self = shift;
    my $member = $self->assert_logged_in or return;
    my $data = $self->load_from_subsession();
    if (! $data) {
        $self->subsession_not_found();
        return;
    }

    if (! $data->{is_edit}) {
        $data->{member_id} = $member->{id};
    }
    local $data->{start_on_date} = $data->{start_on_date};
    local $data->{start_on_time} = $data->{start_on_time};
    local $data->{start_on} = $data->{start_on};
    if (! $data->{start_on}) {
        delete $data->{start_on};
    }

    my $start_on;
    my $start_on_date = delete $data->{start_on_date};
    my $start_on_time = delete $data->{start_on_time};
    if ($start_on_date) {
        $data->{start_on} = sprintf(
            "%s %s",
            $start_on_date,
            $start_on_time || '00:00'
        );
    }
    if (! $data->{signup_url}) {
        # Make sure there's aun undef in there
        $data->{signup_url} = undef;
    }
    $self->SUPER::commit();
}

1;
