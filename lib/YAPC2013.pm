package YAPC2013;
use Mojo::Base 'Mojolicious';
use YAPC2013::Container;
use YAPC2013::Renderer;
use YAPC2013::L10N;
use Plack::Session;
use HTML::FillInForm::Lite;
use Data::Dumper;

has container => sub { YAPC2013::Container->new };

sub development_mode {
    $_[0]->log->info("development mode");
}
sub production_mode {
    $_[0]->log->info("production mode");
}

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->plugin(Config => { file => "etc/config.pl" });
    $self->plugin(Config => { file => "etc/config_local.pl" });
    $self->setup_container;
    $self->setup_xslate;
    $self->setup_routes;

    $self->helper( sessions => sub {
        Plack::Session->new($_[0]->req->env);
    });

    $self->helper( get_member => sub {
        my $self = shift;
        my $member = $self->sessions->get('member');
        return $member;
    });

    $self->hook(around_dispatch => sub {
        my ($next, $c) = @_;
        my $guard = $c->app->container->new_scope;

        # set_lang
        my $lang = $c->req->param('lang')
                || $c->stash->{lang}
                || $c->sessions->get('lang');
        $lang = 'ja' if ( !$lang && $c->req->env->{HTTP_ACCEPT_LANGUAGE} =~ /ja/ );
        $lang = 'en' if ( ( $lang || '' ) ne 'en' && ( $lang || '' ) ne 'ja' );

        $c->stash->{lang} = $lang;
        if( ($c->sessions->get('lang') || '' ) ne $lang ){
            $c->sessions->set(lang => $lang);
        }

        $next->();
        undef $guard;

    });
}

sub setup_routes {
    my $self = shift;
    my $r = $self->routes;

    $r->namespace('YAPC2013::Controller');

    $r->route('/')->to(cb => sub {
        shift->redirect_to("/2013/");
    });

    #notices
    $r->route("/2013/notices/:action")->to(controller => 'notices');

    #login 
    $r->get("/2013/login")->to("auth#index");
    $r->get("/2013/logout")->to("auth#logout");
    #auth
    my $auth = $r->under("/2013/auth");
    $auth->get("/")->to("auth#index");
    $auth->get("/index")->to("auth#index");
    $auth->get("/auth_twitter")->to("auth#auth_twitter");

    # member
    my $member = $r->under("/2013/member");
    $member->get("/")->to("member#index");
    $member->get("/index")->to("member#index");
    $member->get("/show/:object_id")->to("member#show");
    foreach my $action ( qw(index email_edit) ){
        $member->get($action)->to("member#$action");
    }
    foreach my $action ( qw(email_confirm email_submit) ){
        $member->post($action)->to("member#$action");
    }

    # talk
    my $talk = $r->under("/2013/talk");
    $talk->get("/")->to("talk#index");
    foreach my $action ( qw(show edit delete) ){
        $talk->get("$action/:object_id")->to("talk#$action");
    }
    foreach my $action ( qw(list input preview) ){
        $talk->get($action)->to("talk#$action");
    }
    $talk->post("/check")->to("talk#check");
    $talk->post("/commit")->to("talk#commit");


}

sub setup_xslate {
    my $self = shift;

    my $renderer = $self->renderer;
    my $fif = HTML::FillInForm::Lite->new();
    my $markdown = $self->get('Markdown');
    my $scrubber = $self->get('Scrubber');
    my $loc = $self->get('Localizer');
    $renderer->add_handler(tx => YAPC2013::Renderer->build(
        app => $self,
        syntax => "TTerse",
        cache_dir => $self->home->rel_dir("tmp", "compiled_templates"),
        module => [ "Text::Xslate::Bridge::TT2Like", "Data::Dumper::Concise" ],
        function => {
            dumper => sub{
                my $dumper = Dumper @_;
                return "<pre>" . $dumper . "</pre>";
            },
            loc => sub {
                $self->loc(@_);
            },
            fillinform => Text::Xslate::html_builder(sub {
                my $html =  shift;
                if ( my $fill = Text::Xslate->current_vars->{fif} ){
                    $html = (Encode::is_utf8($html))? $html : Encode::decode_utf8($html);
                    return  $fif->fill(\$html, $fill);
                }
                return $html;
            }),
            fmt_talk_abstract => Text::Xslate::html_builder(sub {
                $markdown->markdown( $scrubber->scrub($_[0]) );
            }),
            fmt_member_icon_url => sub {
                $self->get_member_icon_url(@_);
            },
            fmt_member_icon_tag => Text::Xslate::html_builder(sub {
                my $member = shift;
                my $url = $self->get_member_icon_url($member);
                if (! $url) {
                    return <<EOHTML;
<div style="width: 50px; height: 50px; background-color: #999">&nbsp;</div>
EOHTML
                }

                return <<EOHTML;
<a href="/2013/member/show/$member->{id}"><img src="$url" width="50" height="50" /></a>
EOHTML
            }),
            fmt_talk_abstract => Text::Xslate::html_builder(sub {
                $self->get_talk_abstract($_[0], $scrubber, $markdown);
            }),
            fmt_talk_abstract_full => Text::Xslate::html_builder(sub {
                $self->get_talk_abstract($_[0], $scrubber, $markdown);
            }),
            fmt_talk_abstract_short => Text::Xslate::html_builder(sub {
                $self->get_talk_abstract($_[0], $scrubber, $markdown, 140);
            }),
            fmt_talk_abstract_very_short => Text::Xslate::html_builder(sub {
                $self->get_talk_abstract($_[0], $scrubber, $markdown, 70);
            }),
            fmt_error_class => sub {
                my $results = shift;
                if (! defined $results) {
                    return '';
                }

                foreach my $field ( @_ ) {
                    if ( $results->invalid($field) || $results->missing($field)) {
                        return " error";
                    }
                }

                return '';
            },
            fmt_error_message => Text::Xslate::html_builder(sub {
                my $results = shift;
                if (! defined $results) {
                    return '';
                }
                my $fmt = qq|<p class="error">%s</p>|;
                if ( $results->invalid($_[0]) ) {
                    return sprintf $fmt, $self->loc("Invalid value for field '[_1]'", $self->loc($_[1]));
                }

                if ( $results->missing($_[0]) ) {
                    return sprintf $fmt, $self->loc("Missing value for required field '[_1]'", $self->loc($_[1]));
                }
                return '';
            } ),
        }
    ));
    $self->renderer->default_handler('tx');
}

sub applyenv {
    my ($file) = @_;

    my $env = $ENV{DEPLOY_ENV};
    if (! $env ) {
        return ($file);
    }

    my $x_file = $file;
    $x_file =~ s/\.([^\.]+)$/_$env.$1/;
    return ($file, $x_file);
}

sub setup_container {
    my $self = shift;

    my $file = $self->home->rel_file("etc/container.pl");
    my $container = $self->container;
    $container->register(config => $self->config);

    foreach my $f (applyenv($file)) {
        $self->log->info( " - Looking for $file..." );
        if (! -f $f) {
            $self->log->info( "   * nope, not found" );
            next;
        }
        $self->log->info( " + Loading container $file" );
        $self->load_file(
            $f => (
                register => sub (@) { $container->register(@_) }
            )
        );
    }
    $self->helper(get => sub { $container->get($_[1]) });
}

sub load_file {
    my ($self, $file, %args) = @_;

    my $path = Cwd::abs_path($file);
    if (! $path) {
        Carp::croak("$file does not exist");
    }

    if (! -f $path) {
        Carp::confess("$path does not exist, or is not a file");
    }

    return if $INC{$path} && $self->{loaded_paths}{$path}++;
    delete $INC{$path};
    my $pkg = join '::',
        map { my $e = $_; $e =~ s/[\W]/_/g; $e }
        grep { length $_ } (
            'YAPC2013',
            'SafeCompartment',
            File::Spec->splitdir(File::Basename::dirname($path)),
            File::Basename::basename($path)
        )
    ;

    {
        no strict 'refs';
        no warnings 'redefine';
        while ( my ($method, $code) = each %args ) {
            *{ "${pkg}::${method}" } = $code;
        }
    }

    my $code = sprintf <<'EOM', $pkg, $file;
        package %s;
        require '%s';
EOM
    my @ret = eval $code;
    die if $@;
    return @ret;
}


#
# view functions
#
{
    my %langs = (
        'ja' => YAPC2013::L10N->get_handle('ja'),
        'en' => YAPC2013::L10N->get_handle('en'),
    );
    sub loc {
        my ($self, $format, @args) = @_;
        my $lang = Text::Xslate->current_vars->{lang};
        my $l10n = $langs{$lang};
        if( @args ){
            @args =  map { Text::Xslate::html_escape( $_ ) } @args;
            $l10n->maketext( $format, @args);
        } else {
            $l10n->maketext( $format );
        }
    }
}

sub get_talk_abstract{
    my ($self, $talk, $scrubber, $markdown, $max) = @_;
    my $abstract = $talk->{abstract};
    my $len = length $abstract;
    my $truncated = 0;
    if (defined $max && $len >= $max) {
        substr $abstract, $max - 3, $len - ($max - 3), "...";
        $truncated = 1;
    }
    my $html = $markdown->markdown( $scrubber->scrub($abstract) );
    if ($truncated) {
        $html .= qq|\n<p><a href="/2013/talk/show/$talk->{id}">read more...</a></p>|;
    }
    return $html;
}

sub get_member_icon_url {
    my ($self, $member, $size) = @_;

    $size ||= "normal";
    my $key = "member.icon.url.$member->{id}.$size";
    my $memcached = $self->get('Memcached');
    my $url = $memcached->get($key);

    if (! $url) {
        my $authenticated_by = $member->{authenticated_by};
        if ($authenticated_by eq 'facebook') {
            $url = "http://graph.facebook.com/$member->{remote_id}/picture";
            if ($size eq "large") {
                $url .= "?type=large";
            }
        } elsif ($authenticated_by eq 'twitter') {
            $url = "http://api.twitter.com/1/users/profile_image/$member->{nickname}";
warn $url;
            if ($size eq "large") {
                $url .= "?size=original";
            }
        }
        elsif ($authenticated_by eq 'github') {
            my (undef, $code, undef, undef, $body) = $self->get('Furl')->get("https://api.github.com/users/$member->{nickname}");
            if ($code eq 200) {
                my $h = eval { $self->get('JSON')->decode($body) };
                if ($h) {
                    $url = $h->{avatar_url};
                    if ($size eq "large") {
                        # This URL may contain parameters, so use URI
                        $url = URI->new($url);
                        my %q = $url->query_form;
                        $q{s} = 200;
                        $url->query_form(\%q);
                        $url = $url->as_string;
                    }
                }
            }
        }
    }
    if (! $url) {
        return;
    }
    $memcached->set($key, $url, 3600);
    return $url;
}

1;
