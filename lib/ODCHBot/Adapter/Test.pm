package ODCHBot::Adapter::Test;
use Moo;
use Log::Log4perl qw(:easy);

with 'ODCHBot::Role::Adapter';

has messages => (is => 'ro', default => sub { [] });
has actions  => (is => 'ro', default => sub { [] });

sub send_message {
    my ($self, $type, $message, $user, $touser) = @_;
    push @{ $self->messages }, {
        type    => $type,
        message => $message,
        user    => $user   // '',
        touser  => $touser // '',
    };
}

sub send_action {
    my ($self, $action, $target, $message) = @_;
    push @{ $self->actions }, {
        action  => $action,
        target  => $target,
        message => $message // '',
    };
}

# --- Test Helpers ---

sub clear {
    my ($self) = @_;
    @{ $self->messages } = ();
    @{ $self->actions }  = ();
    return $self;
}

sub last_message {
    my ($self) = @_;
    return $self->messages->[-1];
}

sub last_action {
    my ($self) = @_;
    return $self->actions->[-1];
}

sub message_count {
    my ($self) = @_;
    return scalar @{ $self->messages };
}

sub messages_matching {
    my ($self, $pattern) = @_;
    return grep { $_->{message} =~ $pattern } @{ $self->messages };
}

sub simulate_chat {
    my ($self, $user, $text) = @_;
    my $bot = $self->bot;

    # Try command dispatch
    my $cp = $bot->config->get('cp') // '-';
    my $ctx;
    if ($text =~ /^\Q$cp\E/) {
        $ctx = $bot->dispatch_command($user, $text);
        $self->_deliver($ctx) if $ctx;
    }

    # Fire line hook
    my $results = $bot->emit_hook('line', user => $user, chat => $text);
    $self->_deliver_hook_results($results);

    return $ctx;
}

sub simulate_login {
    my ($self, %args) = @_;
    my $bot = $self->bot;

    my ($user, $is_new) = $bot->users->connect_user(%args);
    my $results = $bot->emit_hook('postlogin', user => $user, is_new => $is_new);
    $self->_deliver_hook_results($results);

    return $user;
}

sub simulate_logout {
    my ($self, $name) = @_;
    my $bot = $self->bot;

    my $user = $bot->users->disconnect_user($name);
    my $results = $bot->emit_hook('logout', user_name => $name, user => $user);
    $self->_deliver_hook_results($results);

    return $user;
}

sub simulate_timer {
    my ($self) = @_;
    my $results = $self->bot->emit_hook('timer');
    $self->_deliver_hook_results($results);
}

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
