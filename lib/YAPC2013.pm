package YAPC2013;
use Mojo::Base 'Mojolicious';
use YAPC2013::Container;
use YAPC2013::Renderer;
use YAPC2013::L10N;
use Plack::Session;
use HTML::FillInForm::Lite;
use Data::Dumper;
use utf8;

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
        my $localizer = $self->get('Localizer');

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

        $localizer->set_languages( $lang );

        $next->();
        undef $guard;

    });
}

sub setup_routes {
    my $self = shift;
    my $r = $self->routes;

    push @{$r->namespaces}, 'YAPC2013::Controller';

    $r->route('/')->to(cb => sub {
        shift->redirect_to("/2013/");
    });

    #notices
    $r->route("/2013/notices/:action")->to(controller => 'notices');

    #individual_sponsors
    $r->route("/2013/individual_sponsors/")->to(controller => 'individual_sponsors', action => 'index');

    #login 
    $r->get("/2013/login")->to("auth#index");
    $r->get("/2013/logout")->to("auth#logout");

    #vote
    my $vote = $r->under("/2013/vote");
    $vote->get("/")->to("vote#ballot");
    $vote->get("/form")->to("vote#form");
    $vote->get("/list/:date")->to("vote#list");
    $vote->get("/ballot")->to("vote#ballot");
    $vote->post("/cast")->to("vote#cast");
    $vote->post("/cancel")->to("vote#cancel");

    #auth
    my $auth = $r->under("/2013/auth");
    $auth->get("/")->to("auth#index");
    $auth->get("/index")->to("auth#index");
    $auth->get("/auth_twitter")->to("auth#auth_twitter");
    $auth->get("/auth_fb")->to("auth#auth_fb");
    $auth->get("/auth_github")->to("auth#auth_github");

    # member
    my $member = $r->under("/2013/member");
    $member->get("/")->to("member#index");
    $member->get("/index")->to("member#index");
    $member->get("/show/:object_id")->to("member#show");
    foreach my $action ( qw(index email_edit complete confirm) ){
        $member->get($action)->to("member#$action");
    }
    foreach my $action ( qw(email_confirm email_submit confirm) ){
        $member->post($action)->to("member#$action");
    }

    my $mk_crud = sub {
        my $name = shift;
        my $base = $r->under("/2013/$name");
        $base->get("/")->to("$name#index");
        foreach my $action ( qw(show edit) ){
            $base->get("$action/:object_id")->to("$name#$action");
        }
        foreach my $action ( qw(list input preview schedule) ){
            $base->get($action)->to("$name#$action");
        }
        foreach my $action ( qw(delete) ) {
            $base->post("$action/:object_id")->to("$name#$action");
        }
        foreach my $action ( qw(check commit) ) {
            $base->post($action)->to("$name#$action");
        }
    };

    foreach my $crud_object ( qw(talk event) ) {
        $mk_crud->($crud_object);
    }

    $r->get('/2013/api/talk/list')->to('talk#api_list');
    $r->get('/2013/api/talk/show/:object_id')->to('talk#api_show');
    $r->get('/2013/api/timeline/')->to('info#api_timeline');
}

sub setup_xslate {
    my $self = shift;

    my $renderer = $self->renderer;
    my $loc = $self->get('Localizer');
    my $fif = HTML::FillInForm::Lite->new();
    my $markdown = $self->get('Markdown');
    my $scrubber = $self->get('Scrubber');
    my $oembed = $self->get('API::OEmbed');
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
            loc => Text::Xslate::html_builder(sub {
                    $loc->localize(@_);
            } ),
            embed_talk_video => Text::Xslate::html_builder(sub {
                my $url = shift;
                if (! $url) {
                    return $loc->localize("No video available");
                }
                $url = URI->new($url);
                if ($url->host =~ /youtube\.com$/) {
                    my $oembed_url = URI->new( "http://www.youtube.com/oembed" );
                    $oembed_url->query_form(
                        url => $url,
                        format => "json",
                    );
                    return $oembed->html_for( $oembed_url );
                }
                return $url;
            }),
            embed_talk_slide => Text::Xslate::html_builder(sub {
                my $url = shift;
                if (! $url) {
                    return $loc->localize("No slides available");
                }
                $url = URI->new($url);
                if ($url->host =~ /slideshare\.net$/) {
                    my $oembed_url = URI->new( "http://www.slideshare.net/api/oembed/2" ); 
                    $oembed_url->query_form(
                        url => $url,
                        format => "json",
                    );
                    return $oembed->html_for( $oembed_url );
                }
                elsif ($url->host =~ /^docs\.google\.com$/) {
                    # the path should be /presentation/.../pub
                    my $path = $url->path;
                    if ($path =~ s{/pub$}{/embed}) {
                        $url->path($path);
                    }
                    my %form = $url->query_form;
                    $url->query_form(
                        %form,
                        width => 400,
                    );
                    return <<EOHTML;
<iframe src="$url" frameborder="0" width="500" height="450"allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>
EOHTML
                }
                return <<EOTHML;
<a href="$url">$url</a>
EOHTML
            }),
            fillinform => Text::Xslate::html_builder(sub {
                my $html =  shift;
                if ( my $fill = Text::Xslate->current_vars->{fif} ){
                    #$html = (Encode::is_utf8($html))? $html : Encode::decode_utf8($html);
                    return  $fif->fill(\$html, $fill);
                }
                return $html;
            }),
            get_talk_schedule_time => sub {
                my $start_on = $_[0]->{start_on};
                $start_on =~ /(\d{4}-\d{2}-\d{2}) (\d{2}):(\d{2}):00/;
                return { hour => $2, minute => $3 };
            },
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
            fmt_talk_abstract_as_og_description => sub {
                my $text = $self->get_talk_abstract($_[0], $scrubber, $markdown);
                # remove all markup
                $text =~ s{<[^>]+>}{}smg;
                # truncate to 140 chars
                substr $text, 0, 140, '';
                return $text;
            },
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
            fmt_talk_schedule_top => sub {
                my $start_on = $_[0]->{start_on};
                $start_on =~ /(\d{4}-\d{2}-\d{2}) (\d{2}):(\d{2}):00/;
                my $offset = 
                    ( ($1 eq '2013-09-19') ?
                        int($2 - 7) * 60 + int($3 - 30) :
                        int($2) * 60 + int($3) 
                    ) - (9 * 60 + 30);
                return int(($offset / 5) * 26) + 25 - 1;
            },
            fmt_talk_schedule_height => sub {
                my $duration = $_[0]->{duration};
                return ( $duration / 5 ) * 26 - 1;
            },
            fmt_event_description_as_og_description => sub {
                my $text = $self->get_event_description($_[0], $scrubber, $markdown);
                # remove all markup
                $text =~ s{<[^>]+>}{}smg;
                # truncate to 140 chars
                substr $text, 0, 140, '';
                return $text;
            },
            fmt_event_description => Text::Xslate::html_builder(sub {
                $self->get_event_description($_[0], $scrubber, $markdown);
            }),
            fmt_event_description_short => Text::Xslate::html_builder(sub {
                $self->get_event_description($_[0], $scrubber, $markdown, 140);
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

sub get_event_description {
    my ($self, $event, $scrubber, $markdown, $max) = @_;
    my $description = $event->{description};
    my $len = length $description;
    my $truncated = 0;
    if (defined $max && $len >= $max) {
        substr $description, $max - 3, $len - ($max - 3), "...";
        $truncated = 1;
    }
    my $html = $markdown->markdown( $scrubber->scrub($description) );
    if ($truncated) {
        $html .= qq|\n<p><a href="/2013/event/show/$event->{id}">read more...</a></p>|;
    }
    return $html;
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
            $url = $self->get('API::Twitter')->get_user_icon($member->{nickname}, $size);
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
