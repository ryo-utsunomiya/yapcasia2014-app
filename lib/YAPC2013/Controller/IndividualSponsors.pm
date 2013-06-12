package YAPC2013::Controller::IndividualSponsors;
use Mojo::Base 'YAPC2013::Controller::CRUD';
use YAPC2013::Constants;

has file => "var/individual_sponsors.json";

sub index {
    my $self = shift;

    my $cache = $self->get('Memcached');
    my $cache_key = "faces.json-api-1.1";
    my $sponsors = $cache->get($cache_key);
    if (! $sponsors) {
        my $json = $self->get('JSON');
        my $fp;
        if (! open $fp, "<", $self->file) {
            die "Failed to open @{[ $self->file ]}: $!";
        }
        my $data = $json->decode(do { local $/; <$fp> });
        close $fp;

        $sponsors = [];
        foreach my $sponsor (@$data) {
            if (! $sponsor) { # anonymous? 
                push @$sponsors, undef;
            } else {
                push @$sponsors, $twitter_api->get_user_icon($sponsor);
            }
        }

        $cache->set($cache_key, $sponsors, 5 * 60);
    }
    $self->stash( sponsors => $sponsors );
}

1;
