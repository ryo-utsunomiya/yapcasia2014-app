package YAPC2013;
use Mojo::Base 'Mojolicious';
use YAPC2013::Container;
use YAPC2013::Renderer;
use Data::Dumper;
use Plack::Session;
use JSON;
use Data::UUID;

has container => sub { YAPC2013::Container->new };

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->plugin(Config => { file => "etc/config.pl" });
    $self->setup_container;
    $self->setup_xslate;

    # Config
    my $config = $self->plugin('Config', { file => "etc/config_local.pl" });

    # Container
    #$self->helper( config => $config );
    $self->helper( db => sub { YAPC2013::DB->new( connect_info => $config->{DBI} ) } );
    $self->helper( sessions => sub {
        Plack::Session->new($_[0]->req->env);
    });
    $self->helper( json => sub { JSON->new->utf8 } );
    $self->helper( uuid => sub { Data::UUID->new; } );

    $self->hook(around_dispatch => sub {
        my ($next, $c) = @_;
        my $guard = $c->app->container->new_scope;

        $next->();
    });

    # Router
    my $r = $self->routes;
    push @{$r->namespaces}, 'YAPC2013::Controller';

    #my $auth = $r->under("/2013/auth");
    #$r->get('/2013/auth/twitter')->to("auth#auth_twitter");

    $r->route('/')->to(cb => sub {
        shift->redirect_to("/2013/");
    });
    $r->route('/2013/:controller/:action');

}

sub setup_xslate {
    my $self = shift;

    my $renderer = $self->renderer;
    $renderer->add_handler(tx => YAPC2013::Renderer->build(
        app => $self,
        syntax => "TTerse",
        cache_dir => $self->home->rel_dir("tmp", "compiled_templates"),
        module => [ "Text::Xslate::Bridge::TT2Like", "Data::Dumper::Concise" ],
        function => {
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
1;
