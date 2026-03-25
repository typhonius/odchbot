package ODCHBot::Command::Stats;
use Moo;
use ODCHBot::Formatter qw(format_timestamp format_size);
with 'ODCHBot::Role::Command';

has _connections    => (is => 'rw', default => 0);
has _disconnections => (is => 'rw', default => 0);

sub meta_info {{
    name        => 'stats',
    description => 'Show hub statistics',
    usage       => 'stats',
    hooks       => ['init', 'timer'],
}}

sub tables {{
    stats => {
        sid             => { type => 'INTEGER', primary => 1, autoincrement => 1 },
        time            => { type => 'INTEGER', not_null => 1 },
        number_users    => { type => 'INTEGER', default => 0 },
        total_share     => { type => 'INTEGER', default => 0 },
        connections     => { type => 'INTEGER', default => 0 },
        disconnections  => { type => 'INTEGER', default => 0 },
    },
}}

sub execute {
    my ($self, $ctx) = @_;
    my $tz = $self->config->get('timezone') // 'UTC';

    my $current_users = $self->users->online_count;
    my $total_share   = 0;
    for my $user ($self->users->online_users) {
        $total_share += $user->share // 0;
    }

    my $msg = "\nHub Statistics:\n";
    $msg .= "Users online: $current_users\n";
    $msg .= "Total share: " . format_size($total_share) . "\n";
    $msg .= "Connections: " . $self->_connections . "\n";
    $msg .= "Disconnections: " . $self->_disconnections . "\n";

    # Last snapshot
    my $last = $self->db->select_one('stats', '*', undef, { -desc => 'sid' });
    if ($last) {
        $msg .= "Last snapshot: " . format_timestamp($last->{time}, $tz) . "\n";
    }

    $ctx->reply($msg);
}

sub on_init {
    my ($self, $data) = @_;
    $self->db->insert('stats', {
        time           => time(),
        number_users   => 0,
        total_share    => 0,
        connections    => 0,
        disconnections => 0,
    });
}

sub on_timer {
    my ($self, $data) = @_;
    my $total_share = 0;
    for my $user ($self->users->online_users) {
        $total_share += $user->share // 0;
    }

    $self->db->insert('stats', {
        time           => time(),
        number_users   => $self->users->online_count,
        total_share    => $total_share,
        connections    => $self->_connections,
        disconnections => $self->_disconnections,
    });
}

1;
