# /vote/list/2012-09-28
# /vote/list/2012-09-29
# /vote/cast/$talk_id actual vote

package YAPCApp::Controller::Vote;
use Mojo::Base 'YAPCApp::Controller';

sub get_voted_talks {
    my ($self, $ballot_id) = @_;

    my $talk_id;
    my @talks;
    my $member_api = $self->get('API::Member');
    my $talk_api = $self->get('API::Talk');
    my $dbh = $self->get('DB::Master');
    my $sth = $dbh->prepare(<<EOSQL);
        SELECT t.id FROM talk t JOIN vote v
            ON t.id = v.talk_id
            WHERE v.ballot_id = ?
EOSQL
    $sth->execute($ballot_id);
    $sth->bind_columns(\($talk_id));
    while ($sth->fetchrow_arrayref) {
        my $talk = $talk_api->lookup($talk_id);
        $talk->{speaker} = $member_api->lookup($talk->{member_id});
        push @talks, $talk;
    }
    return \@talks;
}

sub form {
    my $self = shift;
}

sub ballot {
    my $self = shift;

    my $ballot_id =
        $self->req->param('ballot_id') ||
        $self->sessions->get('ballot_id')
    ;
    warn $ballot_id;
    if (! $ballot_id) {
        # do nothing
        $self->redirect_to("/2014/vote/form");
        return;
    }
    my $ballot = $self->get('API::Ballot')->lookup($ballot_id);
    if (! $ballot) {
        $self->render_text("Invalid ballot");
        $self->rendered(500);
        return;
    }

    $self->sessions->set("ballot_id", $ballot_id);

    my $talks = $self->get_voted_talks( $ballot_id );

    $self->stash(
        ballot_id => $ballot_id,
        ballot => $ballot,
        talks => $talks
    );
}

sub list {
    my $self = shift;

    my $ballot_id = $self->sessions->get('ballot_id');
    if (! $ballot_id) {
        $self->redirect_to("/2014/vote/ballot");
        return;
    }
    my $ballot = $self->get('API::Ballot')->lookup($ballot_id);
    if (! $ballot) {
        $self->render_text("Invalid ballot");
        $self->rendered(500);
        return;
    }

    my $date = $self->param('date');

    if ($date !~ /^2014-08-(29|30)$/) {
        $self->render_text("Invalid date");
        $self->rendered(500);
        return;
    }

    my @talks = $self->get('API::Talk')->search(
        {
            start_on => { BETWEEN => [ "$date 00:00:00", "$date 23:59:59" ] },
            status   => 'accepted',
        },
        {
            order_by => "start_on ASC"
        }
    );
    my $member_api = $self->get('API::Member');
    foreach my $talk (@talks) {
        $talk->{speaker} = $member_api->lookup($talk->{member_id});
    }

    my @votes = $self->get('API::Vote')->search(
        { ballot_id => $ballot_id }
    );

    $self->stash(
        ballot_id => $ballot_id,
        date  => $date,
        talks => \@talks,
        votes => +{
            map { ($_->{talk_id} => 1) } @votes,
        }
    );
}

sub cast {
    my $self = shift;
    my $ballot_id = $self->sessions->get('ballot_id');
    my $ballot = $self->get('API::Ballot')->lookup( $ballot_id );
    if (! $ballot) {
        $self->render_text( "Ballot not found" );
        $self->rendered(500);
        return;
    }

    my ($max_votes, $refdate);
    my $ticket_type = $ballot->{ticket_type};
    if ($ticket_type eq 'twodays') {
        $max_votes = 4;
        $refdate   = undef; # don't matter
    } else {
        $max_votes = 2;
        $refdate   = $ticket_type eq 'day1' ? '2014-08-29' : '2014-08-30';
    }

    # You can only vote $max_votes, so make sure that the total number
    # of votes you cast don't exceed this number

    my $talk_api = $self->get('API::Talk');
    my $talks = 0;
    my @talks = $self->req->param('talk_id');
    foreach my $talk_id (@talks) {
        my $talk = $talk_api->lookup($talk_id);
        if (! $talk) {
            $self->render_text( "Talk not found" );
            $self->rendered(500);
            return;
        }

        if (defined $refdate && $refdate ne substr $talk->{start_on}, 0, 10) {
            $self->render_text( "You may only vote for talks on $refdate" );
            $self->rendered(500);
            return;
        }

        $talks++;
    }

    if ($talks > $max_votes) {
        $self->render_text("You can only vote for up to $max_votes talks");
        $self->rendered(500);
        return;
    }

    $self->get('API::Vote')->cast( {
        ballot_id => $ballot_id,
        talk_id   => \@talks
    });
    $self->redirect_to("/2014/vote/ballot");
}

sub cancel {
    my $self = shift;

    my $ballot_id = $self->sessions->get('ballot_id');
    my $ballot = $self->get('API::Ballot')->lookup( $ballot_id );
    if (! $ballot) {
        $self->render_text( "Ballot not found" );
        $self->rendered(500);
        return;
    }

    my @talks = $self->req->param('talk_id');

    $self->get('API::Vote')->delete({
        ballot_id => $ballot_id,
        talk_id => { in => \@talks }
    });
    $self->redirect_to('/2014/vote/ballot');
}

1;
