package YAPCApp::API::WithDBI;
use Moo::Role;
use Scalar::Util ();
use SQL::Maker;

with qw(
    YAPCApp::API::WithCache
);

has primary_key => (
    is => 'ro',
    default => sub { 'id' },
    required => 1,
);

has sql_maker => (
    is => 'ro',
    lazy => 1,
    builder => \&_build_sql_maker
);

sub dbh {
    my $self = shift;
    return $self->get('DB::Master');
}

sub _build_sql_maker {
    my $self = shift;
    my $sql_maker = $self->{sql_maker};
    if ( ! $sql_maker ) {
        $sql_maker = SQL::Maker->new( driver => $self->dbh->{Driver}->{Name} );
        $self->{sql_maker} = $sql_maker;
    }
    return $sql_maker;
}

sub table {
    my $self = shift;
    my $table = $self->{table};
    if (! $table) {
        $table = (split /::/, Scalar::Util::blessed $self)[-1];
        $table =~ s/([a-z0-9])([A-Z])/$1_$2/g;
        $table = lc $table;
#        $table = "yapc2013_" .lc $table;
        $self->{table} = $table;
    }
    return $table;
}

sub lookup {
    my ($self, $id) = @_;

    my $obj = ! ref $id && $self->cache_get($self->table => $id);
    if ($obj) {
        return $obj;
    }

    my ($sql, @binds) = $self->sql_maker->select( $self->table, [ '*' ], { $self->primary_key() => $id });
    $obj = $self->dbh->selectrow_hashref($sql, undef, @binds);
    if ($obj) {
        $self->cache_set( [ $self->table => $id ], $obj );
    }
    return $obj;
}

sub search {
    my ($self, $where, $opts) = @_;
    my ($sql, @binds) = $self->sql_maker->select( $self->table, [ '*' ], $where, $opts );
    my $results =  $self->dbh->selectall_arrayref( $sql, { Slice => {} }, @binds );
    return wantarray ? @$results : $results;
}

sub create {
    my ($self, $args) = @_;

    $args->{created_on} ||= \'NOW()';
    my ($sql, @binds) = $self->sql_maker->insert(
        $self->table,
        $args,
    );
    my $dbh = $self->dbh;
    $dbh->do($sql, undef, @binds);
    $self->lookup($dbh->{mysql_insertid} || $args->{id});
}

sub update {
    my ($self, $id, $args) = @_;

    $self->cache_delete( $self->table => $id ) if ! ref $id;
    my ($sql, @binds) = $self->sql_maker->update(
        $self->table,
        $args,
        ref $id eq 'HASH' ? $id : { $self->primary_key() => $id }
    );
    my $dbh = $self->dbh;
    $dbh->do($sql, undef, @binds);
    $self->lookup($id);
}

sub delete {
    my ($self, $id) = @_;

    $self->cache_delete( $self->table => $id ) if ! ref $id;
    my ($sql, @binds) = $self->sql_maker->delete(
        $self->table,
        ref $id eq 'HASH' ? $id : { $self->primary_key() => $id }
    );
    return $self->dbh->do($sql, undef, @binds);
}

sub count {
    my ($self, $where) = @_;
    my ($sql, @binds) = $self->sql_maker->select( $self->table, [ \'COUNT(*)' ], $where );
    my ($count) = $self->dbh->selectrow_array(
        $sql,
        {},
        @binds,
    );
    return $count;
}

no Moo::Role;

1;

