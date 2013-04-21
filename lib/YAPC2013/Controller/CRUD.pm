package YAPC2013::Controller::CRUD;

use Mojo::Base 'YAPC2013::Controller';
use Scalar::Util ();
use String::CamelCase ();

has object_type => sub {
        my $self = shift;
        my $object_type;
        $object_type = Scalar::Util::blessed( $self );
        $object_type =~ s/^YAPC2013::Controller:://;
        $object_type = String::CamelCase::decamelize($object_type);
        return $object_type;
};

has api_name => sub {
        my $self = shift;
        my $api_name;
        $api_name = String::CamelCase::camelize( $self->object_type );
        $api_name = "API::$api_name";
        return $api_name;
};

sub load_object {
    my ($self, $object_id) = @_;
warn "Loading $object_id from " . $self->api_name;
    return $self->get( $self->api_name )->lookup( $object_id );
}

sub show {
    my $self = shift;

    my $object_id = $self->match->captures->{object_id};
    my $object = $self->load_object( $object_id );

    if (! $object) {
        $self->render_text("Not found");
        $self->rendered(404);
        return;
    }

    $self->stash( $self->object_type, $object );
}

sub list {
    my ($self, $c, %args) = @_;

    my $params = $c->req->params->to_hash;
    if ( ! exists $params->{status} && !$args{allow_empty_status}) {
        $params->{status} = 1;
    }

    my $sort = delete $params->{sort};
    if (! $sort) {
        $sort = [ qw(created_on) ];
    }
    if (! ref $sort ) {
        $sort = [ $sort ];
    }


    my $limit = delete $params->{limit};
    if (! $limit || $limit < 1) {
        $limit = 100;
    }

    my $direction = delete $params->{sort_d} || 'DESC';
    my $order_by = join ", ", map { "$_ $direction" } @$sort;
    my @args = (
        $params,
        { order_by => $order_by, limit => $limit },
    );

    my $list = $c->get( $self->api_name )->search(@args);
    $c->stash->{ $self->object_type . "s" } = $list;
}

sub input {
    my $self = shift;
    my $object = $self->load_from_subsession(allow_no_subsession => 1);
    if ($object) {
        $self->stash( fif => $object, is_edit => $object->{is_edit} );
    }
}

sub process_valid_data {}

sub preview_url {
    my ($self, $c) = @_;
    my $url = URI->new(join "/", $c->url_base, $self->namespace, "preview");
    return $url;
}

sub check {
    my $self = shift;
    # check values, send to the preview page (iframe with a OK button)

    my $fv = $self->get('FormValidator');
    my $profile = $self->stash->{profile} || $self->object_type . '.check';

    my $params = $self->req->params->to_hash;
    $self->req->upload("_____dummy_____");
    my $uploads = $self->req->{uploads} || {};
    my $results = $fv->check( { %$params, %$uploads }, $profile);

    if ($results->success) {
        $self->process_valid_data($results);
        my $sha1 = $self->new_subsession( scalar $results->valid );
        my $url = $self->url_for("./preview");
        $url->query->param( p => $sha1 );
        $self->res->headers->header( 'Location' => $url );
        $self->res->code(302);
        $self->rendered();
        return;
    }

    $self->stash(
        fif      => $results->get_input_data,
        results  => $results,
        template => join("/", split(/-/, $self->stash->{controller}), "input"),
    );

    if ($results->valid('is_edit')) {
        $self->stash( is_edit => 1 );
    }
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

sub preview {
    my $self = shift;

    my $object = $self->load_from_subsession();
    if (! $object) {
        $self->subsession_not_found();
        return;
    }

    $self->stash(
        is_edit => $object->{is_edit},
        $self->object_type => $object,
    );
}

sub process_post_commit {}
sub commit {
    my $self = shift;

    my $data = $self->load_from_subsession();
    if (! $data) {
        $self->subsession_not_found();
        return;
    }

    # Load into the actual template.
    if ( $self->req->param('cancel') ) {
        # XXX 今「キャンセルしました画面」が面倒臭い年頃です
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

sub edit {
    my $self = shift;
    my $id = $self->match->captures->{object_id};
    my $object = $self->load_object( $id );
    if (! $object) {
        $self->render_text("Not found");
        $self->rendered(404);
        return;
    }
    $self->stash(
        $self->object_type() => $object,
        fif                  => $object,
        template             => join("/", split(/-/, $self->stash->{controller}), "input"),
        is_edit              => 1,
    );
}

sub delete {
    my $self = shift;
    my $id = $self->match->captures->{object_id};

    my $object = $self->load_object( $id );
    if (! $object) {
        $self->render_text("Not found");
        $self->rendered(404);
        return;
    }
    
    $self->stash( $self->object_type(), $object );
    $self->get($self->api_name)->delete($id);
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
