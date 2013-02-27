package YAPC2013::DB::Schema;
use strict;
use warnings;

use Teng::Schema::Declare;
use Time::Piece;
use YAPC2013::Utils qw(JSON);

table {
    name 'member';
    pk 'id';
    columns qw(
        id remote_id authenticated_by name nickname email
        created_on modified_on
    );
};

table {
    name 'talk';
    pk 'id';
    columns qw(
        id status member_id venue_id title title_en language subtitles category start_on duration
        material_level tags tshirt_size abstract slide_url video_url sort_order calender_entry_id 
        created_on modified_on
    );
};

1;
