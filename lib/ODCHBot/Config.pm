package ODCHBot::Config;
use Moo;
use Carp qw(croak);
use YAML::Syck ();
use File::Basename qw(dirname);
use Cwd qw(abs_path);

has file   => (is => 'ro', required => 1);
has _data  => (is => 'rw', default => sub { {} });
has _dirty => (is => 'rw', default => 0);

# Keys that cannot be modified at runtime
my %PROTECTED = map { $_ => 1 } qw(db commandPath);

sub BUILD {
    my ($self) = @_;
    $self->load;
}

sub load {
    my ($self) = @_;
    croak "Config file not found: " . $self->file unless -f $self->file;

    my $perms = (stat($self->file))[2] & 07777;
    if ($perms & 0044) {
        warn sprintf("Config file %s is readable by group/others (mode %04o). Consider: chmod 600 %s\n",
            $self->file, $perms, $self->file);
    }

    my $raw = YAML::Syck::LoadFile($self->file);
    $self->_data($raw->{config} // $raw);
    $self->_dirty(0);
    return $self;
}

sub reload {
    my ($self) = @_;
    return $self->load;
}

sub get {
    my ($self, $key) = @_;
    return $self->_data unless defined $key;

    # Support dotted keys: db.driver
    my @parts = split /\./, $key;
    my $val = $self->_data;
    for my $part (@parts) {
        return undef unless ref $val eq 'HASH' && exists $val->{$part};
        $val = $val->{$part};
    }
    return $val;
}

sub set {
    my ($self, $key, $value) = @_;
    croak "Cannot modify protected key: $key" if $PROTECTED{$key};
    croak "Key required" unless defined $key;

    $self->_data->{$key} = $value;
    $self->_dirty(1);
    return $self;
}

sub delete_key {
    my ($self, $key) = @_;
    croak "Cannot modify protected key: $key" if $PROTECTED{$key};
    delete $self->_data->{$key};
    $self->_dirty(1);
    return $self;
}

sub save {
    my ($self) = @_;
    YAML::Syck::DumpFile($self->file, { config => $self->_data });
    $self->_dirty(0);
    return $self;
}

sub base_dir {
    my ($self) = @_;
    return dirname(abs_path($self->file));
}

sub db_dsn {
    my ($self) = @_;
    my $db = $self->get('db') or croak "No database config found";
    my $driver = $db->{driver} // 'SQLite';

    if ($driver =~ /^SQLite/) {
        my $path = join('/', $self->base_dir, $db->{path} // 'logs', $db->{database} // 'odchbot.db');
        return "dbi:SQLite:$path";
    }
    elsif ($driver =~ /^(?:mysql|Pg)/) {
        return "dbi:$driver:database=$db->{database};host=$db->{host};port=$db->{port}";
    }
    else {
        return "dbi:$driver:$db->{database}:$db->{host}:$db->{port}";
    }
}

sub db_credentials {
    my ($self) = @_;
    my $db = $self->get('db') // {};
    return ($db->{username} // '', $db->{password} // '');
}

1;
