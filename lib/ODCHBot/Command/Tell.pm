package ODCHBot::Command::Tell;
use Moo;
use ODCHBot::Formatter qw(format_timestamp);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'tell',
    description => 'Leave a message for an offline user',
    usage       => 'tell <user> <message>',
    hooks       => ['postlogin', 'line'],
}}

sub tables {{
    tell => {
        tid      => { type => 'INTEGER', primary => 1, autoincrement => 1 },
        from_uid => { type => 'INTEGER', not_null => 1 },
        to_uid   => { type => 'INTEGER', not_null => 1 },
        time     => { type => 'INTEGER', not_null => 1 },
        message  => { type => 'TEXT',    not_null => 1 },
    },
}}

sub execute {
    my ($self, $ctx) = @_;
    my ($to_name, $message) = $ctx->args =~ /^(\S+)\s+(.+)$/;

    unless ($to_name && $message) {
        $ctx->reply("Usage: tell <user> <message>");
        return;
    }

    my $to_user = $self->users->find_by_name($to_name);
    unless ($to_user) {
        $ctx->reply("$to_name is not a user - no message saved.");
        return;
    }

    if ($self->users->is_online($to_name)) {
        $ctx->reply("$to_name is online right now. Tell them yourself!");
        return;
    }

    $self->db->insert('tell', {
        from_uid => $ctx->user->uid,
        to_uid   => $to_user->uid,
        time     => time(),
        message  => $message,
    });

    $ctx->reply("Message from " . $ctx->user->name . " to $to_name saved and will be delivered next time they login");
}

sub on_postlogin {
    my ($self, $data) = @_;
    my $user = $data->{user} or return;
    return $self->_deliver_tells($user);
}

sub on_line {
    my ($self, $data) = @_;
    my $user = $data->{user} or return;
    return $self->_deliver_tells($user);
}

sub _deliver_tells {
    my ($self, $user) = @_;
    return unless $user && $user->uid;

    my $tells = $self->db->select('tell', '*', { to_uid => $user->uid });
    return unless @$tells;

    my $tz  = $self->config->get('timezone') // 'UTC';
    my $ctx = ODCHBot::Context->new(user => $user, bot => $self->bot);

    for my $tell (@$tells) {
        my $from = $self->users->find_by_uid($tell->{from_uid});
        my $name = $from ? $from->name : 'Unknown';
        my $time = format_timestamp($tell->{time}, $tz);
        $ctx->reply_pm("Message from $name [$time]: $tell->{message}");
    }

    $self->db->delete_rows('tell', { to_uid => $user->uid });
    return $ctx;
}

1;
