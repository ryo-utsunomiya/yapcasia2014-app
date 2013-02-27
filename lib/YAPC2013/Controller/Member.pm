package YAPC2013::Controller::Member;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

sub index {
    my $self = shift;

    $self->render( hoge => 'test');
}

sub show {
    my $self = shift;

    my $db = $self->db;
    my $member = $self->sessions->get('member');

    $self->render( member => Dumper $member );
}

1;
