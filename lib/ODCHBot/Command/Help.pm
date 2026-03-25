package ODCHBot::Command::Help;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'help',
    description => 'Show connection help and troubleshooting',
    usage       => 'help',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $hub     = $self->config->get('hubname') // 'the hub';
    my $website = $self->config->get('website')  // '';
    my $cp      = $self->config->get('cp')       // '-';

    my $msg = <<~HELP;

    Welcome to $hub!

    Connection Troubleshooting:
    - Ensure your client supports the NMDC protocol
    - Check that your share meets the minimum requirement
    - Try a different client if you have connection issues

    Useful Commands:
    - ${cp}commands    List all available commands
    - ${cp}rules       View hub rules
    - ${cp}info        View your user information
    - ${cp}stats       View hub statistics

    Website: $website
    HELP

    $ctx->reply($msg);
}

1;
