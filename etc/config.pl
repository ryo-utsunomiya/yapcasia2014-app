{
    Memcached => +{ servers => [ '127.0.0.1:11211' ] },
    'DB::Master' => [
        'dbi:mysql:dbname=yapc2013',
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
    FormValidator => {
        file => app->home->rel_file( "etc/profiles.pl" )
    }
}
