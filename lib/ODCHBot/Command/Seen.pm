package ODCHBot::Command::Seen;
use Moo;
use ODCHBot::Formatter qw(format_timestamp format_duration);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'seen',
    description => 'Check when a user was last online',
    usage       => 'seen <username>',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: seen <username>");
        return;
    }

    if ($self->users->is_online($name)) {
        my $user = $self->users->find_by_name($name);
        my $dur = format_duration($user->online_duration);
        $ctx->reply("$name is online right now (connected for $dur)");
        return;
    }

    my $user = $self->users->find_by_name($name);
    unless ($user) {
        $ctx->reply("$name has never been seen.");
        return;
    }

    my $tz = $self->config->get('timezone') // 'UTC';
    if ($user->disconnect_time) {
        my $ago = format_duration(time() - $user->disconnect_time);
        my $when = format_timestamp($user->disconnect_time, $tz);
        $ctx->reply("$name was last seen $ago ago ($when)");
    }
    elsif ($user->connect_time) {
        my $when = format_timestamp($user->connect_time, $tz);
        $ctx->reply("$name was last connected at $when");
    }
    else {
        $ctx->reply("$name exists but has no activity records.");
    }
}

1;
