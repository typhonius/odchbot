package ODCHBot::Command::MassMessage;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'massmessage',
    description => 'Send a message to all connected users',
    usage       => 'massmessage <message>',
    permission  => ODCHBot::User::PERM_OPERATOR,
    aliases     => ['mm'],
}}

sub execute {
    my ($self, $ctx) = @_;
    my $message = $ctx->args;

    unless (length($message // '')) {
        $ctx->reply("Usage: massmessage <message>");
        return;
    }

    $ctx->mass_message($message);
}

1;
