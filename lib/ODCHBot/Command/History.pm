package ODCHBot::Command::History;
use Moo;
use ODCHBot::Formatter qw(format_timestamp);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'history',
    description => 'Show recent chat history',
    usage       => 'history [count]',
    hooks       => ['line'],
}}

sub tables {{
    history => {
        hid  => { type => 'INTEGER', primary => 1, autoincrement => 1 },
        time => { type => 'INTEGER', not_null => 1 },
        uid  => { type => 'INTEGER', not_null => 1 },
        chat => { type => 'TEXT',    not_null => 1 },
    },
}}

sub execute {
    my ($self, $ctx) = @_;
    my $count = int($ctx->args || 20);
    $count = 100 if $count > 100;
    $count = 1   if $count < 1;
    my $tz = $self->config->get('timezone') // 'UTC';

    my $rows = $self->db->select('history', '*', undef, { -desc => 'hid' });
    # SQL::Abstract doesn't support LIMIT natively, use array slice
    my @recent = @$rows[0 .. ($count > @$rows ? $#$rows : $count - 1)];
    @recent = reverse @recent;

    my $msg = "\nChat History (last $count lines):\n";
    my %user_cache;

    for my $row (@recent) {
        $user_cache{$row->{uid}} //= $self->users->find_by_uid($row->{uid});
        my $user = $user_cache{$row->{uid}};
        my $name = $user ? $user->name : 'Unknown';
        my $time = format_timestamp($row->{time}, $tz);
        $msg .= "[$time] <$name> $row->{chat}\n";
    }

    $ctx->reply($msg);
}

sub on_line {
    my ($self, $data) = @_;
    my $user = $data->{user} or return;
    my $chat = $data->{chat} // '';

    # Don't log commands
    my $cp = $self->config->get('cp') // '-';
    return if $chat =~ /^\Q$cp\E/;
    return unless length $chat;

    $self->db->insert('history', {
        time => time(),
        uid  => $user->uid,
        chat => $chat,
    });
}

1;
