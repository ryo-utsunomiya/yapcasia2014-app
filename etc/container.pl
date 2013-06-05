use strict;
use Cache::Memcached::Fast;
use DBI;
use Data::FormValidator;
use Data::UUID;
use Data::Localize;
use Furl;
use JSON ();
use HTML::Scrubber;
use Text::Markdown ();

register JSON => JSON->new->utf8;
register Furl => Furl::HTTP->new;
register UUID => Data::UUID->new;
register Markdown => Text::Markdown->new();
register Scrubber => HTML::Scrubber->new(allow => ["a"], rules => [ a => { href => qr{^(?!(?:java)?script)} } ]);
register Localizer => sub {
    my $config = $_[0]->get('config');
    my $dl = Data::Localize->new(auto => 1);
    foreach my $loc ( @{ $config->{ Localizer }->{ localizers } } ) {
        $dl->add_localizer( %$loc );
    }
    $dl->set_languages('ja', 'en');
    return $dl;
};

register Memcached => sub {
    my $config = $_[0]->get('config');
    Cache::Memcached::Fast->new($config->{Memcached});
}, { scoped => 1 };

register 'DB::Master' => sub {
    my $config = $_[0]->get('config');
    DBI->connect(@{$config->{'DB::Master'}});
}, { scoped => 1 };

foreach my $name (qw(Member Email Talk NoticesSubscriptionTemp NoticesSubscription HRForecast MemberTemp OEmbed Twitter Event)) {
    my $key = "API::$name";
    my $klass = "YAPC2013::API::$name";
    eval "require $klass" or die;
    register $key => sub {
        my $c = shift;
        my $config = $c->get('config')->{$key} || {};
        return $klass->new( %$config, container => $c );
    };
}

register 'FormValidator' => sub {
    my $config = $_[0]->get('config');
    Data::FormValidator->new( $config->{FormValidator}->{file} || "etc/profiles.pl" );
};

register 'Session::Store' => sub {
    my $c = shift;
    Plack::Session::Store::Cache->new(
        cache => $c->get('Memcached'),
    )
};

register 'Session::State' => sub {
    my $config = $_[0]->get('config');
    Plack::Session::State::Cookie->new(
        path => "/2013/",
        domain => "yapcasia.org",
        expires => "86400",
        httponly => 1,
        %{ $config->{'Session::State::Cookie'} || {} },
    );
};

