package ODCHBot::Command::Say;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'say',
    description => 'Spoof a message as another user (admin line hook)',
    usage       => 'say',
    permission  => ODCHBot::User::PERM_ADMINISTRATOR,
    hooks       => ['line'],
}}

sub execute {
    my ($self, $ctx) = @_;
    $ctx->reply_public("Nice try " . $ctx->user->name . " - no using say here!");
}

sub on_line {
    my ($self, $data) = @_;
    my $user = $data->{user} // return;
    my $chat = $data->{chat} // return;

    return unless $user->permission_at_least(ODCHBot::User::PERM_ADMINISTRATOR);
    return unless $chat =~ /^!say\s+(\w+)\s+(.+)/;

    my ($spoof_name, $message) = ($1, $2);

    my $ctx = ODCHBot::Context->new(bot => $self->bot, user => $user);
    $ctx->spoof_public($spoof_name, $message);
    $ctx->send_to_ops($user->name . " just used !say => <" . $user->name . "> $chat");
    return $ctx;
}

1;
