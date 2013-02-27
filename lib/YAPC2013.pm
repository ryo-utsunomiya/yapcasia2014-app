package YAPC2013;
use Mojo::Base 'Mojolicious';
use YAPC2013::DB;
use Data::Dumper;
use Plack::Session;
use JSON;
use Data::UUID;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    $self->plugin('xslate_renderer');
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

    # Router
    my $r = $self->routes;
    $r->namespace('YAPC2013::Controller');

    #my $auth = $r->under("/2013/auth");
    #$r->get('/2013/auth/twitter')->to("auth#auth_twitter");

    $r->route('/')->to(cb => sub {
        shift->redirect_to("/2013/");
    });
    $r->route('/2013/:controller/:action');

}

sub setup_xslate {
    my $self = shift;

    $self->plugin( xslate_renderer => {
        template_options => {
            syntax => "TTerse",
            cache_dir => $self->home->rel_dir("tmp", "compiled_templates"),
            module => [ "Text::Xslate::Bridge::TT2Like", "Data::Dumper::Concise" ],
            function => {
            }
        }
    });
}

1;
