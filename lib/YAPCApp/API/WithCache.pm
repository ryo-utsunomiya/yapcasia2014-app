package YAPCApp::API::WithCache;
use Moo::Role;

with 'YAPCApp::API::WithContainer';

has cache_disabled => (
    is => 'rw',
    default => sub { 0 },
);

has cache_expires => (
    is => 'ro',
);

sub cache_key {
    my ($self, @keys) = @_;
    join '.', @keys;
}

sub cache_get {
    my ($self, @keys) = @_;
    return if $self->cache_disabled;

    my $key = $self->cache_key(@keys);
    my $ret = $self->get('Memcached')->get( $key );
    return $ret;
}

sub cache_set {
    my ($self, $key, $value, $expires) = @_;
    return if $self->cache_disabled;

    $key = ref $key eq 'ARRAY' ? $self->cache_key(@$key) : $key;
    $self->get('Memcached')->set( $key, $value, $expires || $self->cache_expires );
}

sub cache_delete {
    my ($self, @keys) = @_;
    return if $self->cache_disabled;

    my $key = $self->cache_key(@keys);
    $self->get('Memcached')->delete( $key );
}

no Moo::Role;

1;
