package GatewayClient;

# HTTP client for the odch-gateway Bot Platform API.
# Provides bot registration, command polling, chat, and key-value storage.
# The bot registers as a virtual user — no NMDC connection needed.

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Log::Log4perl qw(:levels);

my $logger = Log::Log4perl->get_logger('GatewayClient');

sub new {
    my ($class, %opts) = @_;
    my $self = bless {
        base_url => $opts{url} || 'http://127.0.0.1:3000',
        api_key  => $opts{api_key} || '',
        ua       => LWP::UserAgent->new(timeout => 10, keep_alive => 1),
    }, $class;
    $self->{base_url} =~ s/\/+$//;
    return $self;
}

sub _request {
    my ($self, $method, $prefix, $path, $body) = @_;
    my $url = "$self->{base_url}/api/v1$prefix$path";
    my $req = HTTP::Request->new($method => $url);
    $req->header('X-API-Key' => $self->{api_key});
    if ($body) {
        $req->header('Content-Type' => 'application/json');
        $req->content(encode_json($body));
    }
    return _parse_response($self->{ua}->request($req), $url);
}

sub _get    { my ($self, $path) = @_;        $self->_request('GET',    '/bot', $path) }
sub _post   { my ($self, $path, $body) = @_; $self->_request('POST',   '/bot', $path, $body || {}) }
sub _put    { my ($self, $path, $body) = @_; $self->_request('PUT',    '/bot', $path, $body || {}) }
sub _delete { my ($self, $path, $body) = @_; $self->_request('DELETE', '/bot', $path, $body) }

sub _parse_response {
    my ($res, $url) = @_;
    unless ($res->is_success) {
        $logger->warn("API call failed: $url -> " . $res->status_line);
        return undef;
    }
    my $data = eval { decode_json($res->decoded_content) };
    if ($@) {
        $logger->warn("JSON parse error from $url: $@");
        return undef;
    }
    return $data;
}

# -----------------------------------------------------------------------
# Bot Platform API
# -----------------------------------------------------------------------

# Register bot with gateway — creates a virtual user on the hub
sub register {
    my ($self, $nick, $description, $email, $tag, @commands) = @_;
    my $result = $self->_post('/register', {
        nick        => $nick,
        description => $description,
        email       => $email,
        tag         => $tag,
        commands    => \@commands,
    });
    if ($result && $result->{token}) {
        $self->{bot_token} = $result->{token};
    }
    return $result;
}

# Unregister bot — removes the virtual user
sub unregister {
    my ($self, $nick) = @_;
    return $self->_delete('/register', { nick => $nick, token => $self->{bot_token} });
}

# Poll for pending commands dispatched to this bot
sub poll_commands {
    my ($self, $nick) = @_;
    my $token = $self->{bot_token} // '';
    return $self->_get("/commands/pending?nick=$nick&token=$token");
}

# Connect to SSE event stream for real-time command delivery.
# Calls $on_command->($cmd_hashref) for each command event.
# Calls $on_pm->($event_hashref) for each PM event (optional).
# Blocks until the connection drops; caller should reconnect.
sub event_stream {
    my ($self, $nick, $on_command, $on_pm) = @_;
    require IO::Socket::INET;

    my $token = $self->{bot_token} // '';

    # Parse host/port from base_url
    my ($host, $port) = $self->{base_url} =~ m{^https?://([^:/]+)(?::(\d+))?};
    $host //= '127.0.0.1';
    $port //= 80;

    my $sock = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => 10,
    ) or do {
        $logger->error("SSE connect failed: $!");
        return;
    };

    # Send HTTP request
    my $path = "/api/v1/bot/events?nick=$nick&token=$token";
    print $sock "GET $path HTTP/1.1\r\n";
    print $sock "Host: $host:$port\r\n";
    print $sock "X-API-Key: $self->{api_key}\r\n";
    print $sock "Accept: text/event-stream\r\n";
    print $sock "Connection: keep-alive\r\n";
    print $sock "\r\n";

    # Skip HTTP headers
    while (my $line = <$sock>) {
        $line =~ s/\r?\n$//;
        last if $line eq '';
    }

    # Read SSE events
    my $event = '';
    my $data = '';
    while (my $line = <$sock>) {
        $line =~ s/\r?\n$//;

        if ($line =~ /^event:\s*(.+)/) {
            $event = $1;
        }
        elsif ($line =~ /^data:\s*(.+)/) {
            $data = $1;
        }
        elsif ($line eq '' && $event ne '') {
            # End of SSE block
            if ($event eq 'command' && $data ne '') {
                my $cmd = eval { decode_json($data) };
                $on_command->($cmd) if $cmd && !$@;
            }
            elsif ($event eq 'pm' && $data ne '' && $on_pm) {
                my $pm = eval { decode_json($data) };
                $on_pm->($pm) if $pm && !$@;
            }
            $event = '';
            $data = '';
        }
        # SSE comments (keepalive) are just ignored
    }

    close $sock;
}

# Send a chat message as the bot
sub send_chat {
    my ($self, $nick, $message) = @_;
    return $self->_post('/chat', {
        nick    => $nick,
        message => $message,
        token   => $self->{bot_token},
    });
}

# Send a private message as a bot
sub send_pm {
    my ($self, $from, $to, $message) = @_;
    return $self->_post('/pm', {
        from    => $from,
        to      => $to,
        message => $message,
        token   => $self->{bot_token},
    });
}

# -----------------------------------------------------------------------
# Hub API — users and moderation (main API, not bot prefix)
# -----------------------------------------------------------------------

sub get_users {
    my ($self) = @_;
    return $self->_request('GET', '', '/users');
}

sub kick_user {
    my ($self, $nick, $reason) = @_;
    return $self->_request('POST', '', "/users/$nick/kick", { reason => $reason || '' });
}

# -----------------------------------------------------------------------
# Key-value storage — for plugin config and custom data
# -----------------------------------------------------------------------

sub get_data {
    my ($self, $namespace, $key) = @_;
    my $data = $self->_get("/data/$namespace/$key");
    return $data ? $data->{value} : undef;
}

sub set_data {
    my ($self, $namespace, $key, $value) = @_;
    return $self->_put("/data/$namespace/$key", { value => $value });
}

sub delete_data {
    my ($self, $namespace, $key) = @_;
    return $self->_delete("/data/$namespace/$key");
}

sub list_data {
    my ($self, $namespace) = @_;
    my $data = $self->_get("/data/$namespace");
    return $data ? ($data->{entries} || []) : [];
}

1;
