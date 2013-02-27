package YAPC2013::Controller::Talk;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use OAuth::Lite::Consumer;

sub index {
    my $self = shift;
    $self->render( hoge => 'test' );
}

sub show {
    my $self = shift;

    my $page ||= 1;

    my $db = $self->db;
    my ( $rows, $pager ) = $db->search_with_pager(
        'talk',
        +{},
        +{ page => $page, rows => 20 }
    );

    $self->render( talks => $rows, pager => $pager );
}

sub commit {
    my $self = shift;

    my $data = $self->load_from_subsession();
    if (! $data) {
        $self->subsession_not_found();
        return;
    }

    # Load into the actual template.
    if ( $self->req->param('cancel') ) {
        # XXX キャンセル画面
        $self->subsession_not_found();
        return;
    }

    my $object;
    local $data->{is_edit} = $data->{is_edit};
    if ( delete $data->{is_edit} ) {
        local $data->{id} = $data->{id};
        my $id = delete $data->{id};
        $object = $self->load_object( $id );
        if ( ! $object ) {
            $self->render_text("Not found");
            $self->rendered(404);
            return;
        }

        $object = $self->get($self->api_name)->update( $id, $data );
        $self->stash( is_edit => 1 );
    } else {
        delete $data->{id};
        $object = $self->get($self->api_name)->create($data);
    }

    $self->process_post_commit($object);

    $self->delete_subsession( $self->stash->{subsession_id} );
    $self->stash( $self->object_type, $object );
}

sub subsession_not_found {
    my $self = shift;
    $self->render(code => 500, text => 'Could not find subsession' );
}

sub load_from_subsession {
    my ($self, %args) = @_;

    my $subsession_id = $self->req->param('p');
    my $object = $self->subsession( $subsession_id );
    if (! defined $object ) {
        if ( ! $args{allow_no_subsession} ) {
            $self->subsession_not_found();
        }
        return;
    }
    $self->stash(
        subsession_id => $subsession_id,
        subsession    => $object,
    );
    return $object;
}

sub new_subsession {
    my ($self, $data) = @_;

    my $sha1 = Digest::SHA::sha1_hex(time(), {}, $$, rand());
    my $sessions = $self->sessions;
    my $subsessions = $sessions->get('subsession');
    if (! $subsessions) {
        $subsessions = {};
        $sessions->set(subsession => $subsessions);
    }
    my $now = time();
    foreach my $subsession_id ( keys %$subsessions ) {
        my $subsession = $subsessions->{ $subsession_id };
        if ( $subsession->{expires} <= $now ) {
            delete $subsessions->{$subsession_id};
        }
    }
    $subsessions->{ $sha1 } = {
        expires => $now + 900,
        data => $data,
    };
    $self->stash->{ subsession_id } = $sha1;
    return $sha1;

    return $sha1;
}

sub delete_subsession {
    my ($self, $id) = @_;

    my $sessions = $self->sessions();
    my $subsessions = $sessions->get('subsession');
    delete $subsessions->{$id};
}

sub subsession {
    my ($self, $id) = @_;

    my $sessions = $self->sessions;
    my $subsessions = $sessions->get('subsession');
    if (! $subsessions) {
        $subsessions = {};
        $sessions->set(subsession => $subsessions);
    }
    my $data = $subsessions->{ $id };
    if (! $data) {
        return;
    }

    if ($data->{expires} <= time()) {
        delete $subsessions->{ $id };
        return;
    }
    return $data->{data};
}

1;
