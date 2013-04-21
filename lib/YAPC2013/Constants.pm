package YAPC2013::Constants;
use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT;

use Exporter::Constants (
    \@EXPORT => +{
        HOGE => 0,
        VENUE_ID => {
            1 => 'main',
            2 => 'sub1',
            3 => 'sub2',
            4 => 'sub3'
        },
    },
);
