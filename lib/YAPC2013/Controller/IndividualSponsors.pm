package YAPC2013::Controller::IndividualSponsors;
use Mojo::Base 'YAPC2013::Controller::CRUD';
use YAPC2013::Constants;

has file => "var/individual_sponsors.json";

sub index {
    my $self = shift;

    my $cache = $self->get('Memcached');
    my $cache_key = "faces.json";
    my $data = $cache->get($cache_key);
    if (! $data) {
        my $json = $self->get('JSON');
        my $fp;
        if (! open $fp, "<", $self->file) {
            die "Failed to open @{[ $self->file ]}: $!";
        }
        $data = $json->decode(do { local $/; <$fp> });
        close $fp;

        $cache->set($cache_key, $data, 5 * 60);
    }
    $self->stash( sponsors => $data );
}

1;
