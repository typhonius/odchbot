package ODCHBot::Command::Info;
use Moo;
use ODCHBot::Formatter qw(format_timestamp format_duration format_size);
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'info',
    description => 'Show information about a user',
    usage       => 'info [username]',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args || $ctx->user->name;
    my $tz   = $self->config->get('timezone') // 'UTC';

    my $target = $self->users->find_by_name($name);
    unless ($target) {
        $ctx->reply("User '$name' not found.");
        return;
    }

    my $msg = "\nUser Info: " . $target->name . "\n";
    $msg .= "Status: " . ($target->is_online ? 'Online' : 'Offline') . "\n";
    $msg .= "Permission: " . $target->permission_name . "\n";

    if ($target->is_online) {
        $msg .= "Online for: " . format_duration($target->online_duration) . "\n";
        $msg .= "Share: " . format_size($target->share) . "\n";
    }

    if ($target->connect_time) {
        $msg .= "Last connected: " . format_timestamp($target->connect_time, $tz) . "\n";
    }
    if ($target->disconnect_time) {
        $msg .= "Last disconnected: " . format_timestamp($target->disconnect_time, $tz) . "\n";
    }

    # Show IP only to operators+
    if ($ctx->user->permission_at_least(ODCHBot::User::PERM_OPERATOR) && $target->ip) {
        my $ip = $target->ip;
        my $label = ($ip =~ /^(?:10\.|172\.(?:1[6-9]|2\d|3[01])\.|192\.168\.)/) ? 'Internal' : 'External';
        $msg .= "IP: $ip ($label)\n";
    }

    $ctx->reply($msg);
}

1;
