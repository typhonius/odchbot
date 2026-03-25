package ODCHBot::Command::Reload;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'reload',
    description => 'Reload a command module (or all with *)',
    usage       => 'reload <command|*>',
    permission  => ODCHBot::User::PERM_ADMINISTRATOR,
    required    => 1,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: reload <command|*>");
        return;
    }

    if ($name eq '*') {
        # Reload all commands
        $self->_clear_inc_cache();
        $self->bot->commands->discover_and_load;
        $ctx->reply_public("All commands reloaded.");
        return;
    }

    my $cmd = $self->bot->commands->find($name);
    unless ($cmd) {
        $ctx->reply_public("Unable to reload module. Ensure module exists.");
        return;
    }

    my $class = ref $cmd;
    my $file  = $class;
    $file =~ s{::}{/}g;
    $file .= '.pm';
    delete $INC{$file};

    eval { require $file };
    if ($@) {
        $ctx->reply("Failed to reload $name: $@");
        return;
    }

    # Re-instantiate and re-register
    my $new_cmd = eval { $class->new(bot => $self->bot) };
    if ($@ || !$new_cmd) {
        $ctx->reply("Failed to reinstantiate $name: " . ($@ // 'unknown error'));
        return;
    }

    $self->bot->commands->unregister($cmd->name);
    $self->bot->commands->register($new_cmd);
    $ctx->reply_public("$name reloaded.");
}

sub _clear_inc_cache {
    my ($self) = @_;
    for my $key (keys %INC) {
        delete $INC{$key} if $key =~ m{^ODCHBot/Command/};
    }
}

1;
