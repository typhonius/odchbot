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
        ua       => LWP::UserAgent->new(timeout => 10),
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
    return $self->_post('/register', {
        nick        => $nick,
        description => $description,
        email       => $email,
        tag         => $tag,
        commands    => \@commands,
    });
}

# Unregister bot — removes the virtual user
sub unregister {
    my ($self, $nick) = @_;
    return $self->_delete('/register', { nick => $nick });
}

# Poll for pending commands dispatched to this bot
sub poll_commands {
    my ($self, $nick) = @_;
    return $self->_get("/commands/pending?nick=$nick");
}

# Connect to SSE event stream for real-time command delivery.
# Calls $on_command->($cmd_hashref) for each command event.
# Blocks until the connection drops; caller should reconnect.
sub event_stream {
    my ($self, $nick, $on_command) = @_;
    require HTTP::Tiny;
    my $http = HTTP::Tiny->new(timeout => 0);
    my $url = "$self->{base_url}/api/v1/bot/events?nick=$nick";
    my $buf = '';

    $http->request('GET', $url, {
        headers => {
            'X-API-Key' => $self->{api_key},
            'Accept'    => 'text/event-stream',
        },
        data_callback => sub {
            my ($chunk) = @_;
            $buf .= $chunk;
            while ($buf =~ s/^(.*?\n\n)//s) {
                my $block = $1;
                my ($event, $data);
                for my $line (split /\n/, $block) {
                    if ($line =~ /^event:\s*(.+)/) { $event = $1; }
                    elsif ($line =~ /^data:\s*(.+)/) { $data = $1; }
                }
                if (defined $event && $event eq 'command' && defined $data) {
                    my $cmd = eval { decode_json($data) };
                    $on_command->($cmd) if $cmd && !$@;
                }
            }
        },
    });
}

# Send a chat message as the bot
sub send_chat {
    my ($self, $nick, $message) = @_;
    return $self->_post('/chat', {
        nick    => $nick,
        message => $message,
    });
}

# Send a private message as a bot
sub send_pm {
    my ($self, $from, $to, $message) = @_;
    return $self->_post('/pm', {
        from    => $from,
        to      => $to,
        message => $message,
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
