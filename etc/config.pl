my $credentials = require 'credentials.pl';

+{
    %$credentials,
    Memcached => +{ servers => ['127.0.0.1:11211'], namespace => 'yapc2014:' },
    'DB::Master' => [
        'dbi:mysql:dbname=yapc2014',
        'root',
        undef,
        +{
            AutoCommit          => 1,
            PrintError          => 0,
            RaiseError          => 1,
            ShowErrorStatement  => 1,
            AutoInactiveDestroy => 1,
            Callbacks => +{
                connected => sub {
                    shift->do('SET SESSION sql_mode=STRICT_TRANS_TABLES');
                    return;
                },
            },
            mysql_enable_utf8 => 1,
        }
    ],
    Localizer => {
        localizers => [
            { class => 'Gettext', path => app->home->rel_file("gettext/*.po") },
        ]
    },
    FormValidator => {
        file => app->home->rel_file( "etc/profiles.pl" )
    },
    'API::HRForecast' => {
        hf_url => "http://127.0.0.1:5127"
    }
}
