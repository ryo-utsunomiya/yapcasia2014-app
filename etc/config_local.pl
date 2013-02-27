use HTTP::Session::Store::Memcached;
use HTTP::Session::State::Cookie;
use Cache::Memcached::Fast;

warn "config, load 'config_test.pl'";

+{
    ENV => 'test',
    Memcached => +{ servers => [ '127.0.0.1:12345' ] },
    Session => +{
        store =>
            HTTP::Session::Store::Memcached->new(
                memd => Cache::Memcached::Fast->new( +{ servers => [ '127.0.0.1:12345' ] } )
            ),
        state => HTTP::Session::State::Cookie->new(),
    },
    DBI => +[
        'dbi:mysql:dbname=yapc2013_test',
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
    Twitter => {
        consumer_key => '37p1zU3nzcOGELSWawufCg',
        consumer_secret => 'zN48zGLw1d5MfDzssB5R9y4mMFgKzbr0EgOaRsIYdU',
        callback_url => 'http://localhost:3000/2013/auth/auth_twitter'
    },
    FormValidator => {
        file => app->home->rel_file( "etc/profiles.pl" )
    }
};
