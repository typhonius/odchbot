package ODCHBot::Command::Load;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'load',
    description => 'Dynamically load a command module',
    usage       => 'load <command>',
    permission  => ODCHBot::User::PERM_ADMINISTRATOR,
    required    => 1,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: load <command>");
        return;
    }

    if ($self->bot->commands->find($name)) {
        $ctx->reply_public("$name command already loaded.");
        return;
    }

    my $class = "ODCHBot::Command::" . ucfirst(lc($name));
    my $file  = $class;
    $file =~ s{::}{/}g;
    $file .= '.pm';

    eval { require $file };
    if ($@) {
        $ctx->reply("Failed to load $name: $@");
        return;
    }

    my $cmd = eval { $class->new(bot => $self->bot) };
    if ($@ || !$cmd) {
        $ctx->reply("Failed to instantiate $name: " . ($@ // 'unknown error'));
        return;
    }

    $self->bot->commands->register($cmd);
    $ctx->reply_public("$name command loaded.");
}

1;
