package ODCHBot::Command::Ungag;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'ungag',
    description => 'Unmute a user on the hub',
    usage       => 'ungag <username>',
    permission  => ODCHBot::User::PERM_OPERATOR,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: ungag <username>");
        return;
    }

    $ctx->ungag($name);
    $ctx->reply("$name has been ungagged.");
}

1;
