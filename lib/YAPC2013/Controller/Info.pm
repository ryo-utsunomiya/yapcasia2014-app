package YAPC2013::Controller::Info;
use Mojo::Base 'YAPC2013::Controller';

sub api_timeline {
    my $self = shift;

    my $cache = $self->get('Memcached');
    my $cache_key = "tweets.user_timeline.api_timeline";
    my $tweets;
    if( my $data = $cache->get($cache_key) ){
        $tweets = $data;
    } else {
        my $nt = $self->get('API::Twitter');
        $tweets = $nt->twitter->user_timeline({ conut => 10 });
        $cache->set($cache_key, $tweets, 60);
    }
    return $self->render('json', $tweets);
}

1;
