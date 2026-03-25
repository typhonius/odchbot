package ODCHBot::UserStore;
use Moo;
use Carp qw(croak);
use ODCHBot::User;

has db      => (is => 'ro', required => 1);
has _online => (is => 'ro', default => sub { {} });

my %USER_COLUMNS = (
    uid   => { type => 'INTEGER', primary => 1, autoincrement => 1 },
    name  => { type => 'TEXT',    not_null => 1 },
    ip    => { type => 'TEXT',    default => "''" },
    email => { type => 'TEXT',    default => "''" },
    share => { type => 'INTEGER', default => 0 },
    share_delta     => { type => 'INTEGER', default => 0 },
    permission      => { type => 'INTEGER', default => ODCHBot::User::PERM_ANONYMOUS },
    connect_time    => { type => 'INTEGER' },
    disconnect_time => { type => 'INTEGER' },
    description     => { type => 'TEXT',    default => "''" },
    speed           => { type => 'TEXT',    default => "''" },
);

sub BUILD {
    my ($self) = @_;
    $self->db->ensure_table('users', \%USER_COLUMNS);
}

sub _row_to_user {
    my ($self, $row) = @_;
    return unless $row;
    return ODCHBot::User->new(%$row);
}

sub find_by_name {
    my ($self, $name) = @_;
    # Check online cache first
    return $self->_online->{lc $name} if exists $self->_online->{lc $name};

    my $row = $self->db->select_one('users', '*', { name => $name });
    return $self->_row_to_user($row);
}

sub find_by_uid {
    my ($self, $uid) = @_;
    my $row = $self->db->select_one('users', '*', { uid => $uid });
    return $self->_row_to_user($row);
}

sub find_by_email {
    my ($self, $email) = @_;
    my $row = $self->db->select_one('users', '*', { email => $email });
    return $self->_row_to_user($row);
}

sub connect_user {
    my ($self, %args) = @_;
    croak "name required" unless $args{name};

    my $existing = $self->db->select_one('users', '*', { name => $args{name} });
    my $now = time();

    if ($existing) {
        $self->db->update('users', {
            connect_time => $now,
            ip           => $args{ip}    // $existing->{ip},
            permission   => $args{permission} // $existing->{permission},
            share        => $args{share} // $existing->{share},
            description  => $args{description} // $existing->{description},
            speed        => $args{speed} // $existing->{speed},
        }, { uid => $existing->{uid} });

        my $user = $self->_row_to_user({
            %$existing,
            connect_time => $now,
            ip           => $args{ip}    // $existing->{ip},
            permission   => $args{permission} // $existing->{permission},
            share        => $args{share} // $existing->{share},
            description  => $args{description} // $existing->{description},
            speed        => $args{speed} // $existing->{speed},
        });
        $self->_online->{lc $user->name} = $user;
        return ($user, 0);  # (user, is_new)
    }
    else {
        my $uid = $self->db->insert('users', {
            name         => $args{name},
            ip           => $args{ip}          // '',
            permission   => $args{permission}  // ODCHBot::User::PERM_ANONYMOUS,
            share        => $args{share}       // 0,
            connect_time => $now,
            email        => $args{email}       // '',
            description  => $args{description} // '',
            speed        => $args{speed}       // '',
        });

        my $user = ODCHBot::User->new(
            uid          => $uid,
            name         => $args{name},
            ip           => $args{ip}          // '',
            permission   => $args{permission}  // ODCHBot::User::PERM_ANONYMOUS,
            share        => $args{share}       // 0,
            connect_time => $now,
            email        => $args{email}       // '',
            description  => $args{description} // '',
            speed        => $args{speed}       // '',
        );
        $self->_online->{lc $user->name} = $user;
        return ($user, 1);  # (user, is_new)
    }
}

sub disconnect_user {
    my ($self, $name) = @_;
    my $user = delete $self->_online->{lc $name};
    my $now = time();

    $self->db->update('users', { disconnect_time => $now }, { name => $name });

    return $user;
}

sub online_users {
    my ($self) = @_;
    return values %{ $self->_online };
}

sub online_count {
    my ($self) = @_;
    return scalar keys %{ $self->_online };
}

sub is_online {
    my ($self, $name) = @_;
    return exists $self->_online->{lc $name};
}

sub all_users {
    my ($self, %opts) = @_;
    my $rows = $self->db->select('users', '*', $opts{where}, $opts{order});
    return map { $self->_row_to_user($_) } @$rows;
}

1;
