package ODCHBot::Command::Toggle;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'toggle',
    description => 'Enable or disable a command',
    usage       => 'toggle <command>',
    permission  => ODCHBot::User::PERM_OPERATOR,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: toggle <command>");
        return;
    }

    my $cmd = $self->bot->commands->find($name);
    unless ($cmd) {
        $ctx->reply("Unknown command: $name");
        return;
    }

    if ($cmd->required) {
        $ctx->reply("Cannot toggle required command: $name");
        return;
    }

    if ($self->bot->commands->is_disabled($cmd->name)) {
        $self->bot->commands->enable($cmd->name);
        $ctx->reply($cmd->name . " has been enabled.");
    }
    else {
        $self->bot->commands->disable($cmd->name);
        $ctx->reply($cmd->name . " has been disabled.");
    }
}

1;
