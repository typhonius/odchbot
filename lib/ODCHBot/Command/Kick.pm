package ODCHBot::Command::Kick;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'kick',
    description => 'Kick a user from the hub',
    usage       => 'kick <username> [reason]',
    permission  => ODCHBot::User::PERM_OPERATOR,
}}

sub execute {
    my ($self, $ctx) = @_;
    my ($name, $reason) = $ctx->args =~ /^(\S+)(?:\s+(.+))?$/;

    unless ($name) {
        $ctx->reply("Usage: kick <username> [reason]");
        return;
    }

    my $victim = $self->users->find_by_name($name);
    unless ($victim) {
        $ctx->reply("User '$name' not found.");
        return;
    }

    unless ($victim->is_online) {
        $ctx->reply("$name is not online.");
        return;
    }

    unless ($ctx->user->outranks($victim)) {
        $ctx->reply("You cannot kick a user with equal or higher permissions.");
        return;
    }

    $reason //= $self->config->get('kick_default') // 'Kicked by operator';
    $ctx->kick($victim, "You have been kicked: $reason");
    $ctx->reply("$name has been kicked: $reason");
}

1;
