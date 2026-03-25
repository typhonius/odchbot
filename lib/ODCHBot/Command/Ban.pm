package ODCHBot::Command::Ban;
use Moo;
use ODCHBot::User;
use ODCHBot::Formatter qw(format_timestamp format_duration);
with 'ODCHBot::Role::Command';

my %UNITS = (m => 60, h => 3600, d => 86400, w => 604800, y => 31536000);

sub meta_info {{
    name        => 'ban',
    description => 'Temporarily ban a user',
    usage       => 'ban <user> <duration> [reason] (e.g., ban baduser 2d Spam)',
    permission  => ODCHBot::User::PERM_OPERATOR,
    aliases     => ['tban'],
    hooks       => ['prelogin', 'timer'],
}}

sub tables {{
    ban => {
        bid     => { type => 'INTEGER', primary => 1, autoincrement => 1 },
        op_uid  => { type => 'INTEGER', not_null => 1 },
        uid     => { type => 'INTEGER', not_null => 1 },
        time    => { type => 'INTEGER', not_null => 1 },
        expire  => { type => 'INTEGER', not_null => 1 },
        message => { type => 'TEXT', default => "''" },
    },
}}

sub execute {
    my ($self, $ctx) = @_;
    my ($name, $duration, $reason) = $ctx->args =~ /^(\S+)\s+(\d+[mhdwy])\s*(.*)$/;

    unless ($name && $duration) {
        $ctx->reply("Usage: ban <user> <duration> [reason] (e.g., ban user 2d Spam)");
        return;
    }

    my $victim = $self->users->find_by_name($name);
    unless ($victim) {
        $ctx->reply("User '$name' not found.");
        return;
    }

    unless ($ctx->user->outranks($victim)) {
        $ctx->reply("You cannot ban a user with equal or higher permissions.");
        return;
    }

    my ($num, $unit) = $duration =~ /^(\d+)([mhdwy])$/;
    my $seconds = $num * ($UNITS{$unit} // 3600);
    my $expire = time() + $seconds;

    $self->db->insert('ban', {
        op_uid  => $ctx->user->uid,
        uid     => $victim->uid,
        time    => time(),
        expire  => $expire,
        message => $reason // '',
    });

    $ctx->ban($victim);
    $ctx->kick($victim, "You have been banned for $duration" . ($reason ? ": $reason" : ''));
    $ctx->reply("$name banned for $duration" . ($reason ? ": $reason" : ''));
}

sub on_prelogin {
    my ($self, $data) = @_;
    my $user_name = $data->{user_name} or return;

    my $user = $self->users->find_by_name($user_name);
    return unless $user;

    my $ban = $self->db->select_one('ban', '*', { uid => $user->uid });
    return unless $ban;

    if ($ban->{expire} < time()) {
        $self->db->delete_rows('ban', { bid => $ban->{bid} });
        return;
    }

    my $ctx = ODCHBot::Context->new(user => $user, bot => $self->bot);
    $ctx->kick($user, "You are banned until " . format_timestamp($ban->{expire}));
    push @{ $ctx->_responses }, { action => 'reject' };
    return $ctx;
}

sub on_timer {
    my ($self, $data) = @_;
    # Clean up expired bans
    $self->db->do_sql("DELETE FROM ban WHERE expire < ?", time());
}

1;
