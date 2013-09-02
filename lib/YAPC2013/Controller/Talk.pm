package YAPC2013::Controller::Talk;
use Mojo::Base 'YAPC2013::Controller::CRUD';
use YAPC2013::Constants;
use Time::Local;
use feature 'state';

sub index {
    $_[0]->redirect_to("http://yapcasia.org/2013/talk/list");
}

sub schedule {
    my $self = shift;

    my $date = $self->req->param('date');
    if ( !$date ){
        state $day1_start = timelocal(0, 0, 0, 20, 8, 113);
        state $day2_start = timelocal(0, 0, 0, 21, 8, 113);

        my $now = time();
        if ($now < $day1_start) {
            $date = '2013-09-19';
        } elsif ($now < $day2_start) {
            $date = '2013-09-20';
        } else {
            $date = '2013-09-21';
        }
    }
    $self->stash( date => $date );

    my $cache     = $self->get('Memcached');
    my $format    = $self->req->param('format') || 'html';
    my $cache_key = join ".", qw(talk schedule), $format, $date;
    my $data      = $cache->get($cache_key);
    if (! $data) {
        warn "inininin!!!";
        my $talk_api = $self->get('API::Talk');
        my $member_api = $self->get('API::Member');
        my $venues = VENUES;
        my @talks_by_venue;
        foreach my $venue ( @$venues ) {
            my @talks = $talk_api->search(
                {
                    venue_id => $venue->{id},
#                    status   => "accepted",
                    duration => { "!=", 5 },
                    start_on => { "between" => [ "$date 00:00:00", "$date 23:59:59" ] }
                },
                {
                    order_by => "start_on ASC",
                }
            );
            foreach my $talk (@talks) {
                $talk->{speaker} = $member_api->lookup($talk->{member_id});
            }
            push @talks_by_venue, \@talks;
        }

        $data = {
            venues => $venues,
            venue_id2name => VENUE_ID2NAME,
            talks_by_venue => \@talks_by_venue,
            date => $date,
        };

        if ($format eq 'json') {
            foreach my $talks (@talks_by_venue) {
                foreach my $talk (@$talks) {
                    my $speaker = $talk->{speaker};
                    $speaker->{profile_image_url} = $self->app->get_member_icon_url($speaker);
                    delete $speaker->{email};
                    delete $speaker->{is_admin};
                    delete $speaker->{remote_id};
                    delete $speaker->{authenticated_by};
                    delete $speaker->{modified_on};
                    delete $speaker->{updated_on};
                    delete $speaker->{created_on};
                    delete $talk->{tshirt_size};
                }
            }
        }
        $cache->set($cache_key, $data, 60);
    }

    if ($format ne 'html') {
        $self->render($format, $data);
    } else {
        use Data::Dumper;
        warn Dumper $data;
        $self->stash($data);
    }
}

sub list {
    my $self = shift;

    my $talk_api = $self->get('API::Talk');
    my $member_api = $self->get('API::Member');

    my $pending_talks = $talk_api->search(
        { status => 'pending' },
        { order_by => "start_on ASC, created_on DESC" },
    );

    my $accepted_talks = $talk_api->search(
        { status => 'accepted' },
        { order_by => "start_on ASC, created_on DESC" },
    );

    foreach my $talk ( ( @$pending_talks, @$accepted_talks ) ){
        $talk->{speaker} = $member_api->lookup( $talk->{member_id} );
    }

    $self->render( pending_talks => $pending_talks );
    $self->render( accepted_talks => $accepted_talks );
}

sub show {
    my $self = shift;

    $self->SUPER::show();

    if (my $talk = $self->stash->{talk}) {
        my $speaker = $self->get('API::Member')->lookup($talk->{member_id});
        if (my $member = $self->get_member) {
            if ($talk->{member_id} eq $member->{id}) {
                $self->stash( owner => 1 );
            }
            $self->stash( member => $member );
        }

        if( my $venue_id = $talk->{venue_id} ){
            $talk->{venue} = VENUE_ID2NAME->{$venue_id};
        }

        $talk->{speaker} = $speaker;
        $self->stash(
            speaker => $speaker,
        );
    }

    if (my $format = $self->req->param('format')) {
        if ($format eq 'json') {
            # protect some speaker information
            my $talk = $self->stash->{talk};
            my $speaker = $talk->{speaker};
            local $speaker->{authenticated_by};
            local $speaker->{email};
            local $speaker->{is_admin};
            local $speaker->{remote_id};
            delete $speaker->{$_} for qw(authenticated_by email is_admin remote_id);

            $self->render_json( $talk );
        }
    }
}

sub input {
    my $self = shift;
    my $member = $self->assert_email or return;

    # if this is a submission for LT, then we need to switch profile and
    # template that we use here
    my $is_lt = $self->req->param('lt');
    if ($is_lt) {
        $self->stash(
            template => "talk/input_lt",
        );
    }

    if (!$member->{is_admin} && !$is_lt) {
        $self->render_text("Currently talk submissions are disabled");
        $self->rendered(403);
        return;
    }

    $self->SUPER::input();
    $self->stash(venues => VENUES );

    if (my $start_on = $self->stash->{fif}->{start_on} ) {
        my($date, $time) = split / /, $start_on;
        $self->stash->{fif}->{start_on_date} = $date;
        $self->stash->{fif}->{start_on_time} = $time;
    }
}

sub edit {
    my $self = shift;
    my $member = $self->assert_email or return;

    my $id = $self->match->captures->{object_id};
    my $object = $self->load_object( $id );
    if (! $object) {
        $self->render_not_found();
        return;
    }

    if ($member->{id} ne $object->{member_id} && !$member->{is_admin}) {
        $self->render_text("No auth");
        $self->rendered(403);
        return;
    }

    my $is_lt = $self->req->param('lt') || ( $object->{duration} == 5 );
    if ($is_lt) {
        $self->stash(
            profile  => "talk_lt.check",
        )
    }

    $self->SUPER::edit();
    $self->stash(venues => VENUES );

    if (my $start_on = $self->stash->{fif}->{start_on} ) {
        my($date, $time) = split / /, $start_on;
        $self->stash->{fif}->{start_on_date} = $date;
        if ($time !~ /^00:00:00$/) {
            $self->stash->{fif}->{start_on_time} = $time;
        }
    }
    if ($is_lt) {
        $self->stash(
            template => "talk/input_lt",
        );
    } else {
        $self->stash(
            template => "talk/input",
        );
    }

}

sub check {
    my $self = shift;
    my $member = $self->assert_email or return;

    # LT
    my $is_lt = $self->req->param('lt');
    if ($is_lt) {
        $self->stash(
            profile  => "talk_lt.check",
        )
    }
    $self->SUPER::check();

    if ($is_lt) {
        $self->stash(
            template => "talk/input_lt",
        );
    }
}

sub preview {
    my $self = shift;
    my $member = $self->assert_email or return;
    $self->stash( member => $member );

    $self->SUPER::preview();
    $self->stash(venue_id2name => VENUE_ID2NAME );
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

    if ($member->{is_admin}) {
        my $start_on_date = delete $data->{start_on_date};
        my $start_on_time = delete $data->{start_on_time};
        if ($start_on_date) {
            $data->{start_on} = sprintf(
                "%s %s",
                $start_on_date,
                $start_on_time || '00:00'
            );
        } else {
            $data->{start_on} = '0000-00-00 00:00:00';
        }
    }

    $self->SUPER::commit();

    if (! $data->{is_edit}) {
        # all done, send a notification
        my $message;
        {
            local $self->stash->{format} = "eml";
            local $self->stash->{member} = $member;
            $message = $self->render_partial("talk/thankyou");
        }

        $self->get('API::Email')->send_email({
            to      => $member->{email},
            subject => "[YAPC::Asia Tokyho 2013] Thank you for your talk submission!",
            message => $message->to_string,
        });

        my $talk = $self->stash->{talk};
        if ($talk->{duration} != 5) {
            # The url must be protected, so we need to calculate
            # the number of bytes UP to the URL, and it needs to be 58 chars
            my $text = sprintf(
                "New talk submitted%s! '%s'",
                $member->{nickname} ? " by $member->{nickname}" : "",
                $talk->{title} || $talk->{title_en},
            );
            my $length = length $text;
            if ($length > 53) {
                substr $text, 50, $length - 50, '...';
            }
            $self->get('API::Twitter')->post(
                sprintf(
                    "%s %s #yapcasia",
                    $text,
                    "http://yapcasia.org/2013/talk/show/$talk->{id}",
                )
            );
        }
    }

    $self->stash(template => "talk/commit");
}

sub delete {
    my $self = shift;

    my $member = $self->assert_logged_in or return;
    my $id = $self->match->captures->{object_id};
    my $object = $self->load_object( $id );
    if (! $object) {
        $self->render_not_found();
        return;
    }
    if ($member->{id} ne $object->{member_id} && !$member->{is_admin}) {
        $self->render_text("No auth");
        $self->rendered(403);
        return;
    }

    $self->SUPER::delete();
}

sub _serialize_talk {
    my ($self, $talk) = @_;

    my @columns = qw(
        title
        title_en
        language
        subtitles
        category
        venue_id
        start_on
        duration
        material_level
        abstract
        slide_url
        video_url
        photo_permission
        video_permission
    );
    my $serialized = {};
    foreach my $column (@columns) {
        $serialized->{$column} = $talk->{$column};
    }
    my $speaker = $self->get('API::Member')->lookup($talk->{member_id});
    $serialized->{speaker} = {
        name        => $speaker->{name},
        nickname    => $speaker->{nickname},
        service     => $speaker->{authenticated_by}
    };

    # venue... implement later
    $serialized->{venue} = {}; 
    return $serialized;
}

sub api_show {
    my $self = shift;
    $self->show();

    $self->render(json => { talk => $self->_serialize_talk($self->stash->{talk}) });
}

sub api_list {
    my $self = shift;
    my $raw_talks = $self->get('API::Talk')->search(
        { status => 'accepted' },
        { order_by => 'sort_order ASC' },
    );

    my @talks;
    foreach my $talk (@$raw_talks) {
        my $serialized = $self->_serialize_talk($talk);
        push @talks, $serialized;
    }

    $self->render(json => { talks => \@talks });
}

1;
