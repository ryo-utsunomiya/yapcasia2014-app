{
    'DB::Master' => [
        'dbi:mysql:dbname=yapc2013',
        'root',
        undef,
        {
            RaiseError => 1,
            AutoCommit => 1,
            mysql_enable_utf8 => 1,
        }
    ],
}