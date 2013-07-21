package YAPC2013::Constants;
use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT;

use Exporter::Constants (
    \@EXPORT => +{
        VENUES => [
            { id => 1, name => 'main'},
            { id => 2, name => 'sub1'},
            { id => 3, name => 'sub2'},
            { id => 4, name => 'sub3'},
        ],
        VENUE_ID2NAME => {
            1 => 'main',
            2 => 'sub1',
            3 => 'sub2',
            4 => 'sub3',
        },
    },
);
