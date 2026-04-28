package GatewayClient;

# HTTP client for the odch-gateway Bot API.
# Provides bot registration and key-value storage for plugins.
# Core data operations (tells, bans, gags, watches, stats) are
# handled by the gateway's built-in command engine — not the bot.

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

sub _get {
    my ($self, $path) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(GET => $url);
    $req->header('X-API-Key' => $self->{api_key});
    return _parse_response($self->{ua}->request($req), $url);
}

sub _post {
    my ($self, $path, $body) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(POST => $url);
    $req->header('Content-Type' => 'application/json');
    $req->header('X-API-Key' => $self->{api_key});
    $req->content(encode_json($body || {}));
    return _parse_response($self->{ua}->request($req), $url);
}

sub _put {
    my ($self, $path, $body) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(PUT => $url);
    $req->header('Content-Type' => 'application/json');
    $req->header('X-API-Key' => $self->{api_key});
    $req->content(encode_json($body || {}));
    return _parse_response($self->{ua}->request($req), $url);
}

sub _delete {
    my ($self, $path) = @_;
    my $url = "$self->{base_url}/api/v1/bot$path";
    my $req = HTTP::Request->new(DELETE => $url);
    $req->header('X-API-Key' => $self->{api_key});
    return _parse_response($self->{ua}->request($req), $url);
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

# Bot registration — tell the gateway which commands this bot handles
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

# Key-value storage — for plugin config and custom data
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
