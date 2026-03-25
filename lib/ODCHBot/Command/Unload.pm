package ODCHBot::Command::Unload;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'unload',
    description => 'Dynamically unload a command module',
    usage       => 'unload <command>',
    permission  => ODCHBot::User::PERM_ADMINISTRATOR,
    required    => 1,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: unload <command>");
        return;
    }

    my $cmd = $self->bot->commands->find($name);
    unless ($cmd) {
        $ctx->reply_public("$name does not exist: Unable to be unloaded.");
        return;
    }

    if ($cmd->required) {
        $ctx->reply_public($cmd->name . " is required: Unable to be unloaded.");
        return;
    }

    $self->bot->commands->unregister($cmd->name);
    $ctx->reply_public("$name command has been unloaded.");
}

1;
