package YAPC2013::API::Twitter;
use Moo;
use Net::Twitter::Lite::WithAPIv1_1;

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

no Moo;

1;