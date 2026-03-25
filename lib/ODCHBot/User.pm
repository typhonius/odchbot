package ODCHBot::User;
use Moo;
use Carp qw(croak);

# Permission levels (bitwise, matching v3 for backward compatibility)
use constant {
    PERM_OFFLINE        => 0,
    PERM_KEY_NOT_SENT   => 1,
    PERM_KEY_SENT       => 2,
    PERM_ANONYMOUS      => 4,
    PERM_AUTHENTICATED  => 8,
    PERM_OPERATOR       => 16,
    PERM_ADMINISTRATOR  => 32,
    PERM_TELNET         => 64,
};

my %PERM_NAMES = (
    0  => 'Offline',
    1  => 'Key Not Sent',
    2  => 'Key Sent',
    4  => 'Anonymous',
    8  => 'Authenticated',
    16 => 'Operator',
    32 => 'Administrator',
    64 => 'Telnet',
);

has uid             => (is => 'rw');
has name            => (is => 'ro', required => 1);
has permission      => (is => 'rw', default => PERM_ANONYMOUS);
has ip              => (is => 'rw', default => '');
has email           => (is => 'rw', default => '');
has share           => (is => 'rw', default => 0);
has share_delta     => (is => 'rw', default => 0);
has connect_time    => (is => 'rw');
has disconnect_time => (is => 'rw');
has description     => (is => 'rw', default => '');
has speed           => (is => 'rw', default => '');
has client          => (is => 'rw', default => '');
has join_time       => (is => 'rw');
has join_share      => (is => 'rw', default => 0);
has connect_share   => (is => 'rw', default => 0);

sub has_permission {
    my ($self, $required) = @_;
    return ($self->permission & $required) == $required;
}

sub permission_at_least {
    my ($self, $level) = @_;
    return $self->permission >= $level;
}

sub outranks {
    my ($self, $other) = @_;
    return $self->permission > $other->permission;
}

sub is_online {
    my ($self) = @_;
    return defined $self->connect_time
        && (!defined $self->disconnect_time || $self->connect_time > $self->disconnect_time);
}

sub permission_name {
    my ($self) = @_;
    # Find highest matching permission
    for my $level (sort { $b <=> $a } keys %PERM_NAMES) {
        return $PERM_NAMES{$level} if $self->permission >= $level && $level > 0;
    }
    return 'Offline';
}

sub online_duration {
    my ($self) = @_;
    return 0 unless $self->is_online;
    return time() - $self->connect_time;
}

sub TO_JSON {
    my ($self) = @_;
    return {
        uid        => $self->uid,
        name       => $self->name,
        permission => $self->permission,
        ip         => $self->ip,
        online     => $self->is_online,
    };
}

1;
