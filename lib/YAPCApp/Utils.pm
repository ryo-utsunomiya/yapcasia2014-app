package YAPCApp::Utils;
use strict;
use warnings;
use parent qw(Exporter);
use JSON;
use YAPCApp::Constants;

our @EXPORT_OK = qw(random_str JSON);

my @chars = ('a' .. 'z', 'A' .. 'Z', '0' .. '9');
my $_JSON = JSON->new;

sub random_str {
    my $n = shift;
    my $str = '';
    while ( $n-- ) {
        my $char = $chars[rand(@chars)];
        $str .= $char;
    }
    $str;
}

sub JSON { $_JSON; }

1;
