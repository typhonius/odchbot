package ODCHBot::Command::Uptime;
use Moo;
use ODCHBot::Formatter qw(format_duration_short);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'uptime',
    description => 'Show how long the bot has been running',
    usage       => 'uptime',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $uptime = time() - ($self->bot->boot_time // time());
    $ctx->reply("Uptime: " . format_duration_short($uptime));
}

1;
