package YAPC2013::API::Vote;
use Moo;

with 'YAPC2013::API::WithDBI';

sub cast {
    my ($self, $args) = @_;

    my $ballot_id = $args->{ballot_id};

    # group the otes by date.
    my $talk_api = $self->get('API::Talk');
    my %bydate;
    foreach my $talk_id (@{ $args->{talk_id} }) {
        my $talk = $talk_api->lookup($talk_id);
        my $date = substr($talk->{start_on}, 0, 10);;
        push @{ $bydate{ $date } ||= [] }, $talk;
    }

    # only allow the first two talks for each day
    my $dbh = $self->get('DB::Master');
    my $sth = $dbh->prepare(<<EOSQL);
        SELECT v.talk_id
            FROM vote v JOIN talk t
                ON v.talk_id = t.id
            WHERE
                start_on BETWEEN ? AND DATE_ADD(?, INTERVAL 1 DAY)
EOSQL

    foreach my $date( keys %bydate ) {
        my $list = $bydate{$date};
        next unless $list;

        my $length = scalar @$list;
        if ($length > 2) {
            splice @$list, 2, $length - 2;
        }

        # delete votes on these dates.
        my $talk_id;
        $sth->execute( $date, $date );
        $sth->bind_columns( \($talk_id) );
        while ($sth->fetchrow_arrayref) {
            $self->delete( { ballot_id => $ballot_id, talk_id => $talk_id } );
        }
    
        foreach my $talk (@$list) {
            $self->create({
                ballot_id => $ballot_id,
                talk_id   => $talk->{id}
            });
        }
    }
}

no Moo;

1;
