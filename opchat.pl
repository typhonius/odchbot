#!/usr/bin/perl

#--------------------------
# OPChat v5 — Gateway-only OP Group Chat Bot
#
# Registers as a virtual user via the gateway API.
# No NMDC connection — the gateway creates a virtual hub user.
# Receives PMs via SSE and relays them between operators.
#--------------------------

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use Log::Log4perl qw(:levels);
use JSON;

use GatewayClient;

our $VERSION = '4.0.0';

# -----------------------------------------------------------------------
# Initialize logging
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
# Load config
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

my $bot_config = $config->{bot} || {};
my $gw_config  = $config->{gateway} || {};
my $nick        = $bot_config->{nick}        || 'OPChat';
my $description = $bot_config->{description} || 'OP Group Chat';
my $email       = $bot_config->{email}       || 'opchat@dc.glo5.com';
my $tag         = $bot_config->{tag}         || "<opchat V:$VERSION>";

# -----------------------------------------------------------------------
# Initialize Gateway client
# -----------------------------------------------------------------------
my $gateway = GatewayClient->new(
    url     => $gw_config->{url} || 'http://127.0.0.1:3000',
    api_key => $gw_config->{api_key} || '',
);

# -----------------------------------------------------------------------
# Register with gateway — no commands (OPChat only receives PMs)
# -----------------------------------------------------------------------
sub do_register {
    my $result = $gateway->register(
        nick        => $nick,
        description => $description,
        email       => $email,
        tag         => $tag,
        events      => [qw(pm)],
    );
    if ($result && $result->{token}) {
        $logger->info("Registered with gateway as $nick (subscribed to pm)");
        return 1;
    } else {
        $logger->warn("Registration failed");
        return 0;
    }
}

do_register() or die "Initial registration failed\n";

# -----------------------------------------------------------------------
# Shutdown handler — unregister on exit
# -----------------------------------------------------------------------
my $running = 1;

$SIG{INT} = $SIG{TERM} = sub {
    $logger->info("Caught signal, shutting down...");
    $running = 0;
};

END {
    if (defined $gateway && defined $nick) {
        $logger->info("Unregistering $nick from gateway");
        eval { $gateway->unregister($nick) };
    }
}

# -----------------------------------------------------------------------
# Relay helper — send a PM to all online ops
# -----------------------------------------------------------------------

sub relay_to_ops {
    my ($message, $exclude_nick) = @_;
    my $data;
    eval { $data = $gateway->get_users() };
    if ($@) {
        $logger->warn("Failed to get users: $@");
        return;
    }
    return unless $data && ref $data->{users} eq 'ARRAY';

    for my $user (@{$data->{users}}) {
        next unless $user->{is_op};
        next if defined $exclude_nick && $user->{nick} eq $exclude_nick;
        next if $user->{nick} eq $nick;
        $gateway->send_pm($nick, $user->{nick}, $message);
    }
}

# -----------------------------------------------------------------------
# Main loop — SSE event stream with reconnect + re-register
# -----------------------------------------------------------------------
my $reconnect_delay = 2;

while ($running) {
    $logger->info("Connecting to gateway event stream...");

    eval {
        $gateway->event_stream($nick, sub {
            my ($event_type, $event_data) = @_;

            if ($event_type eq 'pm') {
                my $from = $event_data->{from_nick} // return;
                my $msg  = $event_data->{message}   // return;

                $logger->info("OP message from $from: $msg");
                relay_to_ops("<$from> $msg", $from);
            }
        });
    };

    last unless $running;

    # event_stream returns when the connection drops
    $logger->warn("Event stream disconnected, reconnecting in ${reconnect_delay}s...");
    sleep($reconnect_delay);

    # Re-register — gateway may have restarted, wiping our token
    unless (do_register()) {
        $logger->warn("Re-registration failed, will retry...");
    } else {
        $reconnect_delay = 2;
    }

    $reconnect_delay = ($reconnect_delay * 2 > 60) ? 60 : $reconnect_delay * 2;
}

$logger->info("Main loop exited, shutting down");
