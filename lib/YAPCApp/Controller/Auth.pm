package YAPCApp::Controller::Auth;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use OAuth::Lite::Consumer;

sub index {
    my $self = shift;

    my $error = $self->req->param('error');
    $self->render( error => $error );
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

sub auth_twitter {
    my $self = shift;

    my $config = $self->app->config;
    my $verifier = $self->req->param('oauth_verifier');

    if ( my $denied = $self->req->param('denied') ){
        $self->redirect_to( "/2013/login?error=access_denied" );
        return;
    }

    my $consumer = OAuth::Lite::Consumer->new(
        consumer_key       => $config->{Twitter}->{consumer_key},
        consumer_secret    => $config->{Twitter}->{consumer_secret},
        site               => q{https://api.twitter.com},
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
            url    => q{http://api.twitter.com/1.1/account/verify_credentials.json},
            token  => $access_token,
        );
        my $tw = $self->get('JSON')->decode($res->decoded_content);

        my $member = {
            remote_id => $tw->{id},
            nickname  => $tw->{screen_name},
            name      => $tw->{name},
            authenticated_by => "twitter",
        };

        $self->create_member( $member );
    }
}

sub auth_fb {
    my $self = shift;

    my $req   = $self->req;
    my $code  = $req->param('code');
    my $error = $req->param('error');
    if ( $error) {
        if ( $error eq 'access_denied' ){
            $self->redirect_to( "/2013/login?error=access_denied" );
            return;
        } else {
            return;
        }
    } elsif ( ! $code) {
        my $fb_state = Digest::SHA::sha1_hex( Digest::SHA::sha1_hex( time(), {}, rand(), $$ ) );
        $self->sessions->set('fb_s', $fb_state);
        my $uri = URI->new( "https://www.facebook.com/dialog/oauth" );
        $uri->query_form(
            client_id => $self->config->{Facebook}->{client_id},
            redirect_uri => "http://yapcasia.org/2013/auth/auth_fb",
            scope => "email",
            state => $fb_state
        );
        $self->redirect_to( $uri );
    } elsif ($code) {
        my $state = $req->param('state');
        my $expected_state = $self->sessions->get('fb_s');
        if ($state ne $expected_state) {
            die "Fuck";
        }
        my $uri = URI->new( "https://graph.facebook.com/oauth/access_token" );
        $uri->query_form(
            client_id => $self->config->{Facebook}->{client_id},
            redirect_uri => "http://yapcasia.org/2013/auth/auth_fb",
            client_secret => $self->config->{Facebook}->{client_secret},
            code => $code
        );

        my (undef, $h_code, undef, $h_hdrs, $h_body);

        for (1..5) {
            eval {
                (undef, $h_code, undef, $h_hdrs, $h_body) = $self->get('Furl')->get($uri);
            };
            last unless $@;
            last if $h_code eq 200;
            select(undef, undef, undef, rand());
        }

        if ($h_code ne 200) {
            die "HTTP request to fetch access token failed: $h_code: $h_body";
        }
        my $res = URI->new( "?$h_body" );
        my %q   = $res->query_form;
        $uri = URI->new( "https://graph.facebook.com/me" );
        $uri->query_form(
            access_token => $q{access_token}
        );
        (undef, $h_code, undef, $h_hdrs, $h_body) = $self->get('Furl')->get($uri);

        my $fb = $self->get('JSON')->decode($h_body);
        my %member = (
            remote_id => $fb->{id},
            nickname  => $fb->{username} || $fb->{name} || "No Name",
            name      => $fb->{name} || $fb->{username} || "No Name",
            authenticated_by => "facebook",
        );
        if ($fb->{email}) {
            $member{email} = $fb->{email};
        }

        $self->create_member(\%member);
    } else {
        die;
    }
}


sub auth_github {
    my $self = shift;

    my $req   = $self->req;
    my $code  = $req->param('code');
    my $error = $req->param('error');
    if ( $error) {
        if ( $error eq 'access_denied' ){
            $self->redirect_to( "/2013/login?error=access_denied" );
            return;
        } else {
            return;
        }
    } elsif ( ! $code) {
        my $github_state = Digest::SHA::sha1_hex( Digest::SHA::sha1_hex( time(), {}, rand(), $$ ) );
        $self->sessions->set('github_s', $github_state);
        
        my $redirect_uri = URI->new( "http://yapcasia.org/2013/auth/auth_github" );
        $redirect_uri->query_form(
            state => $github_state
        );
        my $uri = URI->new( "https://github.com/login/oauth/authorize" );
        $uri->query_form(
            client_id => $self->config->{Github}->{client_id},
            redirect_uri => $redirect_uri,
            state => $github_state
        );
        $self->redirect_to( $uri );
    } elsif ($code) {
        my $state = $req->param('state');
        my $expected_state = $self->sessions->get('github_s');
        if ($state ne $expected_state) {
            $self->render_text( "Expected state token didn't match for github login" );
            $self->rendered(500);
            return;
        }

        my $uri = URI->new( "https://github.com/login/oauth/access_token" );
        my ($h_code, $h_body);
        (undef, $h_code, undef, undef, $h_body) = $self->get('Furl')->post(
            $uri,
            [],
            [
                client_id => $self->config->{Github}->{client_id},
                client_secret => $self->config->{Github}->{client_secret},
                code => $code
            ]
        );

        if ($h_code ne 200) {
            die "HTTP request to fetch access token failed: $h_code: $h_body";
        }

        # Too fucking lazy to load an XML parsing module here
        if ($h_body !~ /access_token=([\w]+)/) {
            $self->render_text( "Failed to get access token" );
            $self->rendered(500);
            return;
        }

        my $access_token = $1;
        $uri = URI->new("https://api.github.com/user");
        $uri->query_form(
            access_token => $access_token
        );

        (undef, $h_code, undef, undef, $h_body) = $self->get('Furl')->get($uri);

        my $gb = $self->get('JSON')->decode($h_body);

        my %member = (
            remote_id => $gb->{id},
            nickname  => $gb->{login} || $gb->{name} || "No name",
            name      => $gb->{name} || $gb->{login} || "No name",
            authenticated_by => "github",
        );
        if ($gb->{email}) {
            $member{email} = $gb->{email};
        }

        $self->create_member(\%member);
    } else {
        warn "REALLY FUCK";
    }
}


sub create_member {
    my ($self, $member) = @_;

    my $api = $self->get('API::Member');
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

use Data::Dumper;
warn Dumper($object);

    $self->sessions->set(member => $object);

    my $url = $self->sessions->get('after_login');
    if ($url) {
        $self->sessions->remove('after_login');
    } else {
        $url = "/2013/member/show/$object->{id}";
    }
    $self->redirect_to($url);
}


1;
