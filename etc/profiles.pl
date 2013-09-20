use strict;
use URI;
use Data::FormValidator::Constraints qw(email);

+{
    "email.check" => {
        required => [ qw(email) ],
        constraint_methods => {
            email => email(),
        }
    },
    "talk.check" => {
        optional => [ qw(id is_edit status profile_url video_url slide_url venue_id start_on_date start_on_time) ],
        required => [ qw(
            language
            subtitles
            duration
            category
            material_level
            tshirt_size
            abstract
            photo_permission
            video_permission
        ) ],
        require_some => {
            titles => [ 1, qw(title title_en) ]
        },
        dependency_groups => {
            start_on_components => [ qw/start_on_date start_on_time/ ]
        },
        constraint_methods => {
            title => sub {
                my ($dfv, $value) = @_;
                return length( $value ) <= 100 && length( $value ) > 0;
            },
            title_en => sub {
                my ($dfv, $value) = @_;
                return length( $value ) <= 100 && length( $value ) > 0;
            },
            status => qr/^(pending|accepted|rejected)$/,
            language => qr/^(en|ja)$/,
            subtitles => qr/^(en|ja|none)$/,
            tshirt_size => qr/^(none|XS|S|M|L|XL|XXL|XXXL)$/,
            material_level => qr/^(advanced|regular|beginner)$/,
            duration => qr/^(60|40|20|10|5)$/,
            category => qr/^(tutorial|app|infra|library|other|community|testing)$/,
            slide_url => sub {
                 my ($dfv, $value) = @_;
                 warn $value;
                 return (length( $value ) == 0 || $value =~ /^https?:\/\//) ;
            },
            video_url => [ qr/^$/, qr/^https?:\/\//i ],
            photo_permission => qr/^(allow|disallow)/,
            video_permission => qr/^(allow|disallow)/,
        },
    },
    "talk_lt.check" => {
        optional => [
            qw(id is_edit status profile_url video_url slide_url venue_id start_on_date start_on_time),
            qw(
            language
            subtitles
            duration
            category
            material_level
            tshirt_size
            )
        ],
        required => [ qw(
            abstract
        ) ],
        defaults => {
            language => 'ja',
            subtitles  => 'ja',
            duration => 5,
            category => 'other',
            material_level => 'beginner',
            tshirt_size => 'none',
        },
        require_some => {
            titles => [ 1, qw(title title_en) ]
        },
        dependency_groups => {
            start_on_components => [ qw/start_on_date start_on_time/ ]
        },
        constraint_methods => {
            status => qr/^(pending|accepted|rejected)$/,
            slide_url => [ qr/^$/, qr/^https?:\/\//i ],
            video_url => [ qr/^$/, qr/^https?:\/\//i ],
        },
    },
    'event.check' => {
        required => [ qw(title description) ],
        optional => [ qw(is_edit id location start_on_date start_on_time duration is_official member_id signup_url) ],
        defaults => {
            location => 'TBD',
            is_official => 0,
        },
        field_filters => {
            signup_url => sub {
                if (length $_[0] <= 0) {
                    return $_[0];
                }
                return URI->new($_[0])->as_string;
            }
        },
        constraint_methods => {
            title => sub {
                my ($dfv, $value) = @_;
                return length( $value ) <= 100 && length( $value ) > 0;
            },
            location => sub {
                my ($dfv, $value) = @_;
                return length( $value ) <= 100 && length( $value ) > 0;
            },
            start_on_date => qr/^\d{4}-\d{2}-\d{2}$/,
            start_on_time => qr/^\d{2}:\d{2}$/,
            duration => qr/^\d+$/,
            is_official => qr/^1|0$/,
            signup_url => sub {
                my ($dfv, $value) = @_;
                !$value || $value =~ qr/^https?:\/\//i;
            },
        },
    },
};


