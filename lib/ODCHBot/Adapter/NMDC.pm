package ODCHBot::Adapter::NMDC;
use Moo;
use Carp qw(croak);
use Log::Log4perl qw(:easy);

with 'ODCHBot::Role::Adapter';

use ODCHBot::Context;
use ODCHBot::User;

# --- Protocol → Bot Translation ---

sub on_init {
    my ($self) = @_;
    my $bot = $self->bot or croak "Adapter not connected to bot";
    $bot->init;

    # Register the bot itself as a user on the hub
    my $desc  = $bot->bot_desc;
    my $speed = $bot->bot_speed;
    my $email = $bot->bot_email;
    my $share = $bot->bot_share;
    my $tag   = $bot->bot_tag;

    my $myinfo = "\$MyINFO \$ALL " . $bot->bot_name
        . " $desc<$tag>\$\$\$$speed\x01\$$email\$$share\$|";

    eval { odch::data_to_all($myinfo) };
}

sub on_main_chat {
    my ($self, $user_name, $chat) = @_;
    my $bot = $self->bot;

    my $user = $bot->users->find_by_name($user_name);
    return unless $user;

    # Try command dispatch first
    my $cp = $bot->config->get('cp') // '-';
    if ($chat =~ /^\Q$cp\E/) {
        my $ctx = $bot->dispatch_command($user, $chat);
        $self->_deliver($ctx) if $ctx;
    }

    # Always fire the line hook (for history, karma, etc.)
    my $results = $bot->emit_hook('line', user => $user, chat => $chat);
    $self->_deliver_hook_results($results);
}

sub on_pre_login {
    my ($self, $user_name, $ip) = @_;
    my $bot = $self->bot;

    # Validate username
    my $min = $bot->config->get('min_username') // 3;
    my $max = $bot->config->get('username_max_length') // 35;
    my $anon = $bot->config->get('username_anonymous') // 'Anonymous';

    if (length($user_name) < $min) {
        return 0;  # Reject
    }
    if (length($user_name) > $max) {
        return 0;
    }
    if (lc($user_name) eq lc($anon)) {
        return 0 unless $bot->config->get('allow_anon');
    }

    # Fire prelogin hooks (ban checks etc.)
    my $results = $bot->emit_hook('prelogin', user_name => $user_name, ip => $ip);
    $self->_deliver_hook_results($results);

    # Check if any hook rejected the user
    for my $r (@{ $results // [] }) {
        next unless ref $r eq 'ARRAY';
        for my $resp (@$r) {
            next unless ref $resp eq 'HASH';
            return 0 if $resp->{action} && $resp->{action} eq 'reject';
        }
    }

    return 1;  # Allow
}

sub on_post_login {
    my ($self, $user_name, $ip) = @_;
    my $bot = $self->bot;

    my $type = eval { odch::get_type($user_name) } // ODCHBot::User::PERM_ANONYMOUS;

    my ($user, $is_new) = $bot->users->connect_user(
        name       => $user_name,
        ip         => $ip,
        permission => $type,
    );

    DEBUG "$user_name connected" . ($is_new ? " as new user" : "");

    my $results = $bot->emit_hook('postlogin', user => $user, is_new => $is_new);
    $self->_deliver_hook_results($results);
}

sub on_user_disconnect {
    my ($self, $user_name) = @_;
    my $bot = $self->bot;

    my $user = $bot->users->disconnect_user($user_name);
    DEBUG "$user_name disconnected" if $user;

    my $results = $bot->emit_hook('logout', user_name => $user_name, user => $user);
    $self->_deliver_hook_results($results);
}

sub on_timer {
    my ($self) = @_;
    my $results = $self->bot->emit_hook('timer');
    $self->_deliver_hook_results($results);
}

# --- Bot → Protocol Translation ---

sub send_message {
    my ($self, $type, $message, $user, $touser) = @_;
    my $bot_name = $self->bot->bot_name;

    if ($type == ODCHBot::Context::HUB_PUBLIC) {
        odch::data_to_all("<$bot_name> $message|");
    }
    elsif ($type == ODCHBot::Context::PUBLIC_SINGLE) {
        odch::data_to_user($user, "\$To: $user From: $bot_name \$<$bot_name> $message|")
            if $user;
    }
    elsif ($type == ODCHBot::Context::BOT_PM) {
        odch::data_to_user($user, "\$To: $user From: $bot_name \$<$bot_name> $message|")
            if $user;
    }
    elsif ($type == ODCHBot::Context::PUBLIC_ALL) {
        odch::data_to_all("<$bot_name> $message|");
    }
    elsif ($type == ODCHBot::Context::MASS_MESSAGE) {
        odch::data_to_all("\$To: $user From: $bot_name \$<$bot_name> $message|");
    }
    elsif ($type == ODCHBot::Context::SEND_TO_OPS) {
        eval { odch::data_to_ops("<$bot_name> $message|") };
    }
    elsif ($type == ODCHBot::Context::HUB_PM) {
        odch::data_to_user($user, "\$To: $user From: $bot_name \$<$bot_name> $message|")
            if $user;
    }
    elsif ($type == ODCHBot::Context::SPOOF_PUBLIC) {
        odch::data_to_all("<$user> $message|");
    }
    elsif ($type == ODCHBot::Context::RAW) {
        odch::data_to_user($user, "$message|") if $user;
    }
    elsif ($type == ODCHBot::Context::SEND_TO_ADMINS) {
        eval { odch::data_to_admins("<$bot_name> $message|") };
    }
}

sub send_action {
    my ($self, $action, $target, $message) = @_;

    if ($action eq 'kick') {
        # Send PM with reason before kicking
        if ($message) {
            eval { $self->send_message(ODCHBot::Context::BOT_PM, $message, $target) };
        }
        eval { odch::kick_user($target) };
    }
    elsif ($action eq 'nickban') {
        eval { odch::add_nickban_entry($target) };
    }
    elsif ($action eq 'unnickban') {
        eval { odch::remove_nickban_entry($target) };
    }
    elsif ($action eq 'gag') {
        eval { odch::add_gag_entry($target) };
    }
    elsif ($action eq 'ungag') {
        eval { odch::remove_gag_entry($target) };
    }
}

# --- Internal ---

sub _deliver {
    my ($self, $ctx) = @_;
    return unless $ctx && $ctx->has_responses;

    for my $resp ($ctx->responses) {
        if ($resp->{action}) {
            $self->send_action($resp->{action}, $resp->{target}, $resp->{message});
        }
        else {
            $self->send_message($resp->{type}, $resp->{message}, $resp->{user}, $resp->{touser});
        }
    }
}

sub _deliver_hook_results {
    my ($self, $results) = @_;
    return unless $results;

    for my $result (@$results) {
        if (ref $result && $result->isa('ODCHBot::Context')) {
            $self->_deliver($result);
        }
    }
}

1;
