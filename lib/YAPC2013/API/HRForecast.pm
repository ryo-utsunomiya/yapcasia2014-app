package YAPC2013::API::HRForecast;
use Moo;
use POSIX ();

with 'YAPC2013::API::WithContainer';

has 'hf_url' => (is => 'ro');

sub record {
    my ($self, $service, $section, $graph, $count, $epoch) = @_;
    my $furl = $self->get('Furl');
    my $url = sprintf
        '%s/api/%s/%s/%s',
        $self->hf_url,
        $service,
        $section,
        $graph,
    ;
    my $content = sprintf
        'number=%d&datetime=%s',
        $count,
        POSIX::strftime("%Y-%m-%d %H:%M:%S -0900", localtime($epoch))
    ;
        
    $furl->post($url, [], $content);
}

no Moo;

1;