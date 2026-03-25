package ODCHBot::Command::Watch;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'watch',
    description => 'Get notified when a user logs in or out',
    usage       => 'watch <username> | watch list',
    hooks       => ['postlogin', 'logout'],
}}

sub tables {{
    watch => {
        wid         => { type => 'INTEGER', primary => 1, autoincrement => 1 },
        uid         => { type => 'INTEGER', not_null => 1 },
        watched_uid => { type => 'INTEGER', not_null => 1 },
        time        => { type => 'INTEGER', not_null => 1 },
    },
}}

sub execute {
    my ($self, $ctx) = @_;
    my $arg = $ctx->args;

    unless ($arg) {
        $ctx->reply("Usage: watch <username> or watch list");
        return;
    }

    if (lc($arg) eq 'list') {
        my $watches = $self->db->select('watch', '*', { uid => $ctx->user->uid });
        unless (@$watches) {
            $ctx->reply("You are not watching anyone.");
            return;
        }
        my $msg = "\nYou are watching:\n";
        for my $w (@$watches) {
            my $watched = $self->users->find_by_uid($w->{watched_uid});
            $msg .= "  - " . ($watched ? $watched->name : "uid:$w->{watched_uid}") . "\n";
        }
        $ctx->reply($msg);
        return;
    }

    my $target = $self->users->find_by_name($arg);
    unless ($target) {
        $ctx->reply("User '$arg' not found.");
        return;
    }

    # Check for duplicate
    my $existing = $self->db->select_one('watch', '*', {
        uid         => $ctx->user->uid,
        watched_uid => $target->uid,
    });
    if ($existing) {
        $ctx->reply("You are already watching " . $target->name);
        return;
    }

    $self->db->insert('watch', {
        uid         => $ctx->user->uid,
        watched_uid => $target->uid,
        time        => time(),
    });

    $ctx->reply("Now watching " . $target->name);
}

sub on_postlogin {
    my ($self, $data) = @_;
    my $user = $data->{user} or return;
    return $self->_notify_watchers($user, 'logged in');
}

sub on_logout {
    my ($self, $data) = @_;
    my $user = $data->{user} or return;
    return $self->_notify_watchers($user, 'logged out');
}

sub _notify_watchers {
    my ($self, $user, $action) = @_;
    return unless $user && $user->uid;

    my $watchers = $self->db->select('watch', '*', { watched_uid => $user->uid });
    return unless @$watchers;

    my $ctx = ODCHBot::Context->new(bot => $self->bot);
    for my $w (@$watchers) {
        my $watcher = $self->users->find_by_uid($w->{uid});
        next unless $watcher && $self->users->is_online($watcher->name);
        $ctx->reply_pm($user->name . " has $action.", to => $watcher->name);
    }
    return $ctx;
}

1;
