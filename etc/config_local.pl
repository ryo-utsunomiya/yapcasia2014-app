warn "config, load 'config_test.pl'";

+{
    Memcached => +{ servers => [ '127.0.0.1:11211' ] },
    'DB::Master' => +[
        'dbi:mysql:dbname=yapc2014',
        'root',
        '',
        +{
            AutoCommit          => 1,
            PrintError          => 0,
            RaiseError          => 1,
            ShowErrorStatement  => 1,
            AutoInactiveDestroy => 1,
            Callbacks => +{
                connected => sub {
                    # http://blog.yappo.jp/yappo/archives/000796.html
                    shift->do('SET SESSION sql_mode=STRICT_TRANS_TABLES');
                    return;
                },
            },
            mysql_enable_utf8 => 1,
        }
    ],
    Twitter => { #local dev用 twitter account
        consumer_key => '37p1zU3nzcOGELSWawufCg',
        consumer_secret => 'zN48zGLw1d5MfDzssB5R9y4mMFgKzbr0EgOaRsIYdU',
        callback_url => 'http://localhost:3000/2014/auth/auth_twitter'
    },
    Localizer => {
        localizers => [
            { class => 'Gettext', path => app->home->rel_file("gettext/*.po") },
        ]
    },
    FormValidator => {
        file => app->home->rel_file( "etc/profiles.pl" )
    },
    'Session::State::Cookie' => {
        path => undef,
        domain => undef,
    }
};
