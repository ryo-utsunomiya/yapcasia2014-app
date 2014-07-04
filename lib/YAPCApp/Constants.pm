package YAPCApp::Constants;
use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT;

use Exporter::Constants (
    \@EXPORT => +{
        VENUES => [
            { id => 1, name => 'Main Hall'},
            { id => 2, name => 'Sub Room1'},
            { id => 3, name => 'Sub Room2'},
            { id => 4, name => 'Event Hall'},
        ],
        VENUE_ID2NAME => {
            1 => 'Main Hall',
            2 => 'Sub Room1',
            3 => 'Sub Room2',
            4 => 'Event Hall',
        },
    },
);
