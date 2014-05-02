package YAPCApp::Constants;
use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT;

use Exporter::Constants (
    \@EXPORT => +{
        VENUES => [
            { id => 1, name => 'Main Hall'},
            { id => 2, name => 'Event Hall'},
            { id => 3, name => 'Sub Room1'},
            { id => 4, name => 'Sub Room2'},
        ],
        VENUE_ID2NAME => {
            1 => 'Main Hall',
            2 => 'Event Hall',
            3 => 'Sub Room1',
            4 => 'Sub Room2',
        },
    },
);
