package ODCHBot::Command::Commands;
use Moo;
use ODCHBot::Formatter qw(escape_string);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'commands',
    description => 'List available commands',
    usage       => 'commands [command_name]',
    required    => 1,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $specific = $ctx->args;
    my $cp = escape_string($self->config->get('cp') // '-');

    if ($specific) {
        my $cmd = $self->bot->commands->find($specific);
        unless ($cmd) {
            $ctx->reply("Unknown command: $specific");
            return;
        }

        my $msg = "\n${cp}$specific: " . $cmd->description;
        my @aliases = $cmd->aliases;
        $msg .= "\nAliases: " . join(', ', @aliases) if @aliases;
        my @hooks = $cmd->hooks;
        $msg .= "\nHooks: " . join(', ', @hooks) if @hooks;
        $msg .= "\nUsage: ${cp}" . $cmd->usage if $cmd->usage;
        $ctx->reply($msg);
    }
    else {
        my $msg = "\n";
        for my $cmd (sort { $a->name cmp $b->name } $self->bot->commands->accessible_for($ctx->user)) {
            $msg .= "${cp}" . $cmd->name . ": " . $cmd->description . "\n";
        }
        $ctx->reply($msg);
    }
}

1;
