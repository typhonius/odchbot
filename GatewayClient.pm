package GatewayClient;

# HTTP client for the odch-gateway Bot API.
# All bot data operations go through this module.

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

    # Strip trailing slash
    $self->{base_url} =~ s/\/+$//;

    return $self;
}

# -----------------------------------------------------------------------
# Internal HTTP helpers
# -----------------------------------------------------------------------

sub _get {
    my ($self, $path) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(GET => $url);
    $req->header('X-API-Key' => $self->{api_key});
    my $res = $self->{ua}->request($req);
    return _parse_response($res, $url);
}

sub _post {
    my ($self, $path, $body) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(POST => $url);
    $req->header('Content-Type' => 'application/json');
    $req->header('X-API-Key' => $self->{api_key});
    $req->content(encode_json($body || {}));
    my $res = $self->{ua}->request($req);
    return _parse_response($res, $url);
}

sub _put {
    my ($self, $path, $body) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(PUT => $url);
    $req->header('Content-Type' => 'application/json');
    $req->header('X-API-Key' => $self->{api_key});
    $req->content(encode_json($body || {}));
    my $res = $self->{ua}->request($req);
    return _parse_response($res, $url);
}

sub _delete {
    my ($self, $path) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(DELETE => $url);
    $req->header('X-API-Key' => $self->{api_key});
    my $res = $self->{ua}->request($req);
    return _parse_response($res, $url);
}

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
# Tells
# -----------------------------------------------------------------------

sub create_tell {
    my ($self, $from, $to, $message) = @_;
    return $self->_post('/tells', {
        from_nick => $from,
        to_nick   => $to,
        message   => $message,
    });
}

sub get_pending_tells {
    my ($self, $nick) = @_;
    my $data = $self->_get("/tells/$nick");
    return $data ? ($data->{tells} || []) : [];
}

sub mark_tell_delivered {
    my ($self, $id) = @_;
    return $self->_delete("/tells/$id/deliver");
}

# -----------------------------------------------------------------------
# Bans
# -----------------------------------------------------------------------

sub create_ban {
    my ($self, %opts) = @_;
    return $self->_post('/bans', {
        nick      => $opts{nick},
        ip        => $opts{ip},
        reason    => $opts{reason} || '',
        banned_by => $opts{banned_by},
        expires_at => $opts{expires_at},
    });
}

sub check_ban {
    my ($self, $nick) = @_;
    my $data = $self->_get("/bans/check/$nick");
    return $data ? $data->{banned} : 0;
}

sub delete_ban {
    my ($self, $id) = @_;
    return $self->_delete("/bans/$id");
}

# -----------------------------------------------------------------------
# Users
# -----------------------------------------------------------------------

sub get_user {
    my ($self, $nick) = @_;
    return $self->_get("/users/$nick");
}

sub user_connect {
    my ($self, $nick, $ip, $tls) = @_;
    return $self->_post("/users/$nick/connect", {
        ip  => $ip  || '',
        tls => $tls ? JSON::true : JSON::false,
    });
}

sub user_disconnect {
    my ($self, $nick) = @_;
    return $self->_post("/users/$nick/disconnect", {});
}

# -----------------------------------------------------------------------
# Quotes
# -----------------------------------------------------------------------

sub create_quote {
    my ($self, $nick, $text, $added_by) = @_;
    return $self->_post('/quotes', {
        nick       => $nick,
        quote_text => $text,
        added_by   => $added_by,
    });
}

sub random_quote {
    my ($self, $nick) = @_;
    my $path = '/quotes/random';
    $path .= "?nick=$nick" if $nick;
    my $data = $self->_get($path);
    return $data ? $data->{quote} : undef;
}

# -----------------------------------------------------------------------
# Watches
# -----------------------------------------------------------------------

sub create_watch {
    my ($self, $watcher, $watched) = @_;
    return $self->_post('/watches', {
        watcher_nick => $watcher,
        watched_nick => $watched,
    });
}

sub get_watchers {
    my ($self, $nick) = @_;
    my $data = $self->_get("/watches/$nick");
    return $data ? ($data->{watchers} || []) : [];
}

sub delete_watch {
    my ($self, $watcher, $watched) = @_;
    return $self->_delete("/watches/$watcher/$watched");
}

# -----------------------------------------------------------------------
# Stats
# -----------------------------------------------------------------------

sub get_current_stats {
    my ($self) = @_;
    return $self->_get('/stats/current');
}

sub create_snapshot {
    my ($self, $user_count, $total_share) = @_;
    return $self->_post('/stats/snapshot', {
        user_count  => $user_count,
        total_share => $total_share,
    });
}

# -----------------------------------------------------------------------
# Chat search
# -----------------------------------------------------------------------

sub search_chat {
    my ($self, $query, $nick, $limit) = @_;
    my $path = "/chat/search?q=$query";
    $path .= "&nick=$nick" if $nick;
    $path .= "&limit=$limit" if $limit;
    my $data = $self->_get($path);
    return $data ? ($data->{results} || []) : [];
}

sub first_message {
    my ($self, $nick) = @_;
    my $data = $self->_get("/chat/first/$nick");
    return $data ? $data->{message} : undef;
}

sub last_message {
    my ($self, $nick) = @_;
    my $data = $self->_get("/chat/last/$nick");
    return $data ? $data->{message} : undef;
}

# -----------------------------------------------------------------------
# Gags
# -----------------------------------------------------------------------

sub create_gag {
    my ($self, %opts) = @_;
    return $self->_post('/gags', {
        nick       => $opts{nick},
        reason     => $opts{reason} || '',
        gagged_by  => $opts{gagged_by},
        expires_at => $opts{expires_at},
    });
}

sub check_gag {
    my ($self, $nick) = @_;
    my $data = $self->_get("/gags/check/$nick");
    return $data ? $data->{gagged} : 0;
}

sub delete_gag {
    my ($self, $id) = @_;
    return $self->_delete("/gags/$id");
}

# -----------------------------------------------------------------------
# Key-value storage
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

# -----------------------------------------------------------------------
# Bot registration
# -----------------------------------------------------------------------

sub register {
    my ($self, $nick, @commands) = @_;
    return $self->_post('/register', {
        nick     => $nick,
        commands => \@commands,
    });
}

sub unregister {
    my ($self) = @_;
    return $self->_delete('/register');
}

1;
