package YAPCApp::L10N;
use strict;
use warnings;
use utf8;
use parent 'Locale::Maketext';

my $base;
BEGIN {
    $base =  `pwd`;
    chomp $base;
    warn join('/', $base, 'gettext', 'ja.po');
}

use Locale::Maketext::Lexicon +{
    en        => [ Gettext => join('/', $base, 'gettext', 'en.po') ],
    ja        => [ Gettext => join('/', $base, 'gettext', 'ja.po') ],
    _preload  => 1,
    _auto     => $ENV{DEBUG_L10N} ? 0 : 1,
    _style    => 'gettext',
    _decode   => 1,
};

1;
