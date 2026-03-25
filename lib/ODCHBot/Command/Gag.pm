package ODCHBot::Command::Gag;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'gag',
    description => 'Mute a user on the hub',
    usage       => 'gag <username>',
    permission  => ODCHBot::User::PERM_OPERATOR,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: gag <username>");
        return;
    }

    my $victim = $self->users->find_by_name($name);
    unless ($victim) {
        $ctx->reply("User '$name' not found.");
        return;
    }

    unless ($ctx->user->outranks($victim)) {
        $ctx->reply("You cannot gag a user with equal or higher permissions.");
        return;
    }

    $ctx->gag($victim);
    $ctx->reply("$name has been gagged.");
}

1;
