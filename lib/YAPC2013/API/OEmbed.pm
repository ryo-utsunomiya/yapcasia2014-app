package YAPC2013::API::OEmbed;
use Moo;

with 'YAPC2013::API::WithCache';

sub html_for {
    my ($self, $oembed_url) = @_;

    my $html = $self->cache_get($oembed_url);
    if ($html) {
        return $html;
    }

    my (undef, $code, undef, undef, $body) = $self->get('Furl')->get($oembed_url);
    if ($code !~ /^2\d\d$/) {
        my $url = $oembed_url->query_form->{url};
        return sprintf qq|<a href="%s">%s</a>|, $url, $url;
    }

    my $data = eval { $self->get('JSON')->decode($body) };
    if ($@) {
        my $url = $oembed_url->query_form->{url};
        return sprintf qq|<a href="%s">%s</a>|, $url, $url;
    }
    $data->{html};
}

no Moo;

1;

