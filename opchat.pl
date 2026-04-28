#!/usr/bin/perl

#--------------------------
# OPChat — Standalone NMDC OP Group Chat Bot
#
# Connects to the hub as "OPChat". Operators PM this bot to talk
# in a private group chat visible only to other ops.
# Messages sent to OPChat are relayed to all other ops on the hub.
#--------------------------

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use Log::Log4perl qw(:levels);
use JSON;

use NMDCClient;
use GatewayClient;

our $VERSION = '4.0.0';

# -----------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------
{
    my $conf_file = "$FindBin::Bin/opchat.log4perl.conf";
    if (-f $conf_file) {
        open my $fh, '<', $conf_file or die "Cannot open $conf_file: $!";
        my $conf = do { local $/; <$fh> };
        close $fh;
        $conf =~ s{^(log4perl\.appender\.\w+\.filename=)(?!/)(.+)$}{$1$FindBin::Bin/$2}mg;
        Log::Log4perl->init(\$conf);
    } else {
        Log::Log4perl->easy_init($INFO);
    }
}
my $logger = Log::Log4perl->get_logger('OPChat');
$logger->info("OPChat v$VERSION starting");

# -----------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------
my $config;
eval {
    require YAML::AppConfig;
    my $config_file = "$FindBin::Bin/opchat.yml";
    die "Config not found: $config_file\n" unless -f $config_file;
    my $app_config = YAML::AppConfig->new(file => $config_file);
    $config = $app_config->config();
};
if ($@) {
    $logger->error("Config load failed: $@");
    die $@;
}

my $hub_config = $config->{hub} || {};
my $gw_config  = $config->{gateway} || {};
my $nick = $hub_config->{nick} || 'OPChat';

# -----------------------------------------------------------------------
# Gateway client
# -----------------------------------------------------------------------
my $gateway = GatewayClient->new(
    url     => $gw_config->{url} || 'http://127.0.0.1:3000',
    api_key => $gw_config->{bot_api_key} || '',
);

# -----------------------------------------------------------------------
# Hub connection
# -----------------------------------------------------------------------
my $client;

sub create_client {
    $client = NMDCClient->new(
        host        => $hub_config->{host} || '127.0.0.1',
        port        => $hub_config->{port} || 4012,
        nick        => $nick,
        password    => $hub_config->{password} || '',
        description => $hub_config->{description} || 'OP Group Chat',
        email       => $hub_config->{email} || 'opchat@dc.glo5.com',
        tag         => "<opchat V:$VERSION>",
        speed       => 'LAN(T1)',

        on_pm   => sub { handle_pm(@_) },
        on_chat => sub { },
        on_join => sub { },
        on_quit => sub { },
    );
}

# -----------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------
my $reconnect_delay = 5;
create_client();

while (1) {
    if ($client->connect()) {
        $reconnect_delay = 5;
        $logger->info("Connected as $nick");

        while ($client->is_connected()) {
            $client->poll(500);
        }
        $logger->warn("Disconnected");
    } else {
        $logger->error("Failed to connect");
    }

    $logger->info("Reconnecting in ${reconnect_delay}s...");
    sleep($reconnect_delay);
    $reconnect_delay = ($reconnect_delay * 2 > 300) ? 300 : $reconnect_delay * 2;
    create_client();
}

# -----------------------------------------------------------------------
# PM handler — relay to all other ops
# -----------------------------------------------------------------------

sub handle_pm {
    my ($from_nick, $message) = @_;
    $logger->info("OP message from $from_nick: $message");
    relay_to_ops("<$from_nick> $message", $from_nick);
}

sub get_online_ops {
    my @ops;
    eval {
        my $ua = $gateway->{ua};
        my $url = "$gateway->{base_url}/api/v1/users";
        my $req = HTTP::Request->new(GET => $url);
        $req->header('X-API-Key' => $gateway->{api_key});
        my $res = $ua->request($req);
        if ($res->is_success) {
            my $data = decode_json($res->decoded_content);
            for my $user (@{$data->{users} || []}) {
                push @ops, $user->{nick} if $user->{is_op};
            }
        }
    };
    $logger->warn("Failed to get ops: $@") if $@;
    return @ops;
}

sub relay_to_ops {
    my ($message, $exclude_nick) = @_;
    my @ops = get_online_ops();

    for my $op (@ops) {
        next if defined $exclude_nick && $op eq $exclude_nick;
        next if $op eq $nick;
        $client->send_pm($op, $message);
    }
}
