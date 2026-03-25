package ODCHBot::Database;
use Moo;
use Carp qw(croak);
use DBI;
use SQL::Abstract;

has dsn         => (is => 'ro', required => 1);
has username    => (is => 'ro', default => '');
has password    => (is => 'ro', default => '');
has dbh         => (is => 'lazy');
has sql         => (is => 'lazy');
has _tables     => (is => 'rw', default => sub { {} });

sub _build_dbh {
    my ($self) = @_;
    my $dbh = DBI->connect($self->dsn, $self->username, $self->password, {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
    }) or croak "Database connection failed: $DBI::errstr";

    # Enable WAL mode for SQLite for better concurrent performance
    if ($self->dsn =~ /SQLite/) {
        $dbh->do("PRAGMA journal_mode=WAL");
        $dbh->do("PRAGMA foreign_keys=ON");
    }

    return $dbh;
}

sub _build_sql { SQL::Abstract->new }

sub is_sqlite {
    my ($self) = @_;
    return $self->dsn =~ /SQLite/;
}

# --- Schema Management ---

sub ensure_table {
    my ($self, $name, $columns) = @_;
    return if $self->_tables->{$name};

    unless ($self->table_exists($name)) {
        $self->create_table($name, $columns);
    }
    $self->_tables->{$name} = 1;
    return $self;
}

sub table_exists {
    my ($self, $name) = @_;
    my @tables = $self->dbh->tables(undef, undef, $name, 'TABLE');
    return scalar @tables > 0;
}

sub create_table {
    my ($self, $name, $columns) = @_;
    croak "Columns definition required" unless $columns && ref $columns eq 'HASH';

    my @col_defs;
    for my $col (sort keys %$columns) {
        my $def = $columns->{$col};
        my $sql = "$col $def->{type}";
        $sql .= " PRIMARY KEY" if $def->{primary};
        if ($def->{autoincrement}) {
            $sql .= $self->is_sqlite ? " AUTOINCREMENT" : " AUTO_INCREMENT";
        }
        $sql .= " NOT NULL" if $def->{not_null};
        $sql .= " DEFAULT $def->{default}" if exists $def->{default};
        push @col_defs, $sql;
    }

    my $ddl = "CREATE TABLE IF NOT EXISTS $name (" . join(', ', @col_defs) . ")";
    $self->dbh->do($ddl);
    return $self;
}

sub drop_table {
    my ($self, $name) = @_;
    $self->dbh->do("DROP TABLE IF EXISTS $name");
    delete $self->_tables->{$name};
    return $self;
}

# --- CRUD Operations ---

sub insert {
    my ($self, $table, $data) = @_;
    my ($sql, @bind) = $self->sql->insert($table, $data);
    $self->dbh->do($sql, undef, @bind);
    return $self->dbh->last_insert_id(undef, undef, $table, undef);
}

sub select {
    my ($self, $table, $fields, $where, $order) = @_;
    my ($sql, @bind) = $self->sql->select($table, $fields || '*', $where, $order);
    return $self->dbh->selectall_arrayref($sql, { Slice => {} }, @bind);
}

sub select_one {
    my ($self, $table, $fields, $where, $order) = @_;
    my $rows = $self->select($table, $fields, $where, $order);
    return $rows->[0];
}

sub update {
    my ($self, $table, $data, $where) = @_;
    my ($sql, @bind) = $self->sql->update($table, $data, $where);
    return $self->dbh->do($sql, undef, @bind);
}

sub delete_rows {
    my ($self, $table, $where) = @_;
    my ($sql, @bind) = $self->sql->delete($table, $where);
    return $self->dbh->do($sql, undef, @bind);
}

sub do_sql {
    my ($self, $sql, @bind) = @_;
    return $self->dbh->do($sql, undef, @bind);
}

sub count {
    my ($self, $table, $where) = @_;
    my ($sql, @bind) = $self->sql->select($table, ['COUNT(*) as cnt'], $where);
    my $row = $self->dbh->selectrow_hashref($sql, undef, @bind);
    return $row->{cnt} // 0;
}

sub disconnect {
    my ($self) = @_;
    $self->dbh->disconnect if $self->dbh;
}

1;
