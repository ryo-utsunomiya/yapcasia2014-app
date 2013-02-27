package YAPC2013::Controller::Auth;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use OAuth::Lite::Consumer;

sub index {
    my $self = shift;

    $self->render( hoge => 'test');
}

sub login {
    my $self = shift;
    $self->render();
}

sub logout {
    my $self = shift;
    $self->sessions->remove('member');
    $self->redirect_to( "/2013/login" );
}

# XXX 今回はちゃんと実装する
sub need_email {

}

sub auth_twitter {
    my $self = shift;

    my $config = $self->app->config;
    my $verifier = $self->req->param('oauth_verifier');
    my $consumer = OAuth::Lite::Consumer->new(
        consumer_key       => $config->{Twitter}->{consumer_key},
        consumer_secret    => $config->{Twitter}->{consumer_secret},
        site               => q{http://api.twitter.com},
        request_token_path => q{/oauth/request_token},
        access_token_path  => q{/oauth/access_token},
        authorize_path     => q{/oauth/authorize},
    );
    if (! $verifier) {
        my $request_token = $consumer->get_request_token(
            callback_url => $config->{Twitter}->{callback_url},
        );

        $self->sessions->set( request_token => $request_token );
        $self->redirect_to( $consumer->url_to_authorize(
            token        => $request_token,
        ) );
    } else {
        my $request_token = $self->sessions->get('request_token');
        my $access_token = $consumer->get_access_token(
            token    => $request_token,
            verifier => $verifier,
        );
        $self->sessions->remove('request_token');
        my $res = $consumer->request(
            method => 'GET',
            url    => q{http://api.twitter.com/1/account/verify_credentials.json},
            token  => $access_token,
        );
        my $tw = $self->app->json->decode($res->decoded_content);

        my $member = {
            remote_id => $tw->{id},
            nickname  => $tw->{screen_name},
            name      => $tw->{name},
            authenticated_by => "twitter",
            email => ''
        };

        $self->create_member( $member );
    }
}

sub create_member {
    my ($self, $member) = @_;

    my $db = $self->app->db;
    my $old = $db->single(
        'member' => +{
            remote_id => $member->{remote_id},
            authenticated_by => $member->{authenticated_by}
        }
    );

    my $object;
    if( $old ){
        $old->update( $member );
        $object = $old->refetch();
    } else {
        my $uuid = $self->app->uuid;
        $member->{id} = lc( $uuid->create_str() );
        $object = $db->insert(
            'member' => $member
        );
    }


=pod
    my ($old) = $api->search({
        remote_id => $member->{remote_id},
        authenticated_by => $member->{authenticated_by},
    });

    my $object;
    if ($old) {
        $api->update( $old->{id}, $member );
        $object = $api->lookup($old->{id});
    } else {
        my $uuid = $self->get('UUID');
        $member->{id} = lc($uuid->create_str());
        $object = $self->get('API::Member')->create($member);
    }
=cut

    $self->sessions->set(member => $object->get_columns );

    my $url = $self->sessions->get('after_login');
    if ($url) {
        $self->sessions->remove('after_login');
    } else {
        $url = "/2013/member/show/$object->{id}";
    }
    $self->redirect_to($url);
}

1;
