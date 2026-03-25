package ODCHBot::Command::Alert;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'alert',
    description => 'Set a repeating hub-wide alert message',
    usage       => 'alert <minutes> <message> | alert off',
    permission  => ODCHBot::User::PERM_OPERATOR,
    hooks       => ['timer'],
}}

sub execute {
    my ($self, $ctx) = @_;
    my $args = $ctx->args;

    if (lc($args // '') eq 'off') {
        $self->config->set('alert_message', '');
        $self->config->set('alert_time_spacing', 0);
        $ctx->reply("Alert disabled.");
        return;
    }

    my ($interval, $message) = $args =~ /^(\d+)\s+(.+)$/;
    unless ($interval && $message) {
        $ctx->reply("Usage: alert <minutes> <message> | alert off");
        return;
    }

    $self->config->set('alert_message', $message);
    $self->config->set('alert_time_spacing', $interval * 60);
    $self->config->set('alert_last_sent', 0);
    $ctx->reply("Alert set: '$message' every ${interval} minutes.");
}

sub on_timer {
    my ($self, $data) = @_;
    my $message  = $self->config->get('alert_message') // return;
    return unless length $message;

    my $spacing  = $self->config->get('alert_time_spacing') // return;
    return unless $spacing > 0;

    my $last = $self->config->get('alert_last_sent') // 0;
    return if (time() - $last) < $spacing;

    $self->config->set('alert_last_sent', time());

    my $ctx = ODCHBot::Context->new(bot => $self->bot);
    $ctx->reply_hub($message);
    return $ctx;
}

1;
