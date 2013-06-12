package YAPC2013::API::Twitter;
use Moo;
use Net::Twitter::Lite::WithAPIv1_1;
use Scalar::Util qw/blessed/;

with 'YAPC2013::API::WithCache';

has twitter => (
    is => 'rw',
    lazy => 1,
    builder => 'build_twitter',
);

has consumer_key => (
    is => 'rw',
    required => 1,
);

has consumer_secret => (
    is => 'rw',
    required => 1,
);

has access_token => (
    is => 'rw',
    required => 1,
);

has access_token_secret => (
    is => 'rw',
    requried => 1,
);

sub build_twitter {
    my $self = shift;
    return Net::Twitter::Lite::WithAPIv1_1->new(
        consumer_key        => $self->consumer_key,
        consumer_secret     => $self->consumer_secret,
        access_token        => $self->access_token,
        access_token_secret => $self->access_token_secret
    );
}

sub post {
    my ($self, $tweet) = @_;

    if (length $tweet > 140) {
        substr $tweet, 137, length($tweet) - 137, "...";
    }

    eval {
        $self->twitter->update($tweet);
    };
    if ($@) {
        warn "Failed to post to twitter: $@";
    }
}

sub get_user {
    my ($self, $screen_name) = @_;

    my $memcached = $self->container->get('Memcached');
    my $key = $self->cache_key( blessed $self , 'get_user', $screen_name );
    my $user = $self->cache_get($key);

    if( $user ){
        my $get_data = $self->cache_get($key);
        return $user;
    } else {
        my $tw_user = 
            eval{ $self->twitter->show_user({screen_name => $screen_name}) };
        if( $@ ){
            warn "API::Twitter $@ '\@$screen_name'";
            $self->cache_set($key, '', 60 * 60 * 24);
        }
        elsif ( !$tw_user ){
            $self->cache_set($key, '', 60 * 60 * 24);
        }
        else {
            $self->cache_set($key, $tw_user, 60 * 60 * 24);
        }
        return $tw_user;
    }
}

sub get_user_icon {
    my ($self, $screen_name, $size) = @_;

    my $tw_user = $self->get_user($screen_name);
    my $icon = $tw_user->{profile_image_url};

    if( $icon && $size && $size eq 'bigger' || $size eq 'large' ) {
        $icon =~ s/_normal/_bigger/;
    }
    return $icon;
}

no Moo;

1;
