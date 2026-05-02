#!/usr/bin/perl

#--------------------------
# ODCHBot v5 — Gateway-only Bot Client
#
# Registers as a virtual user via the gateway API.
# No NMDC connection — the gateway creates a virtual hub user.
# Commands live in commands/ as separate .pm modules.
#--------------------------

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/commands";
use Log::Log4perl qw(:levels);

use GatewayClient;

our $VERSION = '4.0.0';

# -----------------------------------------------------------------------
# Initialize logging
# -----------------------------------------------------------------------
{
    my $conf_file = "$FindBin::Bin/odchbot.log4perl.conf";
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
my $logger = Log::Log4perl->get_logger('ODCHBot');
$logger->info("Dragon v$VERSION starting");

# -----------------------------------------------------------------------
# Load config
# -----------------------------------------------------------------------
my $config;
eval {
    require YAML::AppConfig;
    my $config_file = "$FindBin::Bin/odchbot.yml";
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
my $nick        = $bot_config->{nick}        || 'Dragon';
my $description = $bot_config->{description} || 'Hub Bot';
my $email       = $bot_config->{email}       || '';
my $tag         = $bot_config->{tag}         || "<odchbot V:$VERSION>";

# -----------------------------------------------------------------------
# Initialize Gateway client
# -----------------------------------------------------------------------
my $gateway = GatewayClient->new(
    url     => $gw_config->{url} || 'http://127.0.0.1:3000',
    api_key => $gw_config->{api_key} || '',
);

# -----------------------------------------------------------------------
# Load command modules from commands/
# -----------------------------------------------------------------------
my %commands;    # name => module package
my %aliases;     # alias => name

my $cmd_dir = "$FindBin::Bin/commands";
if (-d $cmd_dir) {
    opendir(my $dh, $cmd_dir) or $logger->warn("Cannot open $cmd_dir: $!");
    if ($dh) {
        for my $file (sort readdir $dh) {
            next unless $file =~ /^(\w+)\.pm$/;
            my $modname = "commands::$1";
            eval { require "$cmd_dir/$file"; };
            if ($@) {
                $logger->warn("Failed to load command $1: $@");
                next;
            }
            my $name = eval { $modname->name() } || $1;
            $commands{$name} = $modname;
            # Register aliases
            my @al = eval { $modname->aliases() };
            for my $a (@al) {
                $aliases{$a} = $name;
            }
            $logger->debug("Loaded command: $name");
        }
        closedir $dh;
    }
}
$logger->info("Loaded " . scalar(keys %commands) . " commands: " . join(', ', sort keys %commands));

# -----------------------------------------------------------------------
# Register with gateway — declare bot identity and commands
# -----------------------------------------------------------------------
my @all_cmds = (keys %commands, keys %aliases);

sub do_register {
    my $result = $gateway->register($nick, $description, $email, $tag, @all_cmds);
    if ($result && $result->{token}) {
        $logger->info("Registered with gateway as $nick, claiming " . scalar(@all_cmds) . " commands");
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
# Main loop — SSE event stream with reconnect + re-register
# -----------------------------------------------------------------------
my $reconnect_delay = 2;

while ($running) {
    $logger->info("Connecting to gateway event stream...");

    eval {
        $gateway->event_stream($nick, sub {
            my ($cmd_event) = @_;
            my $from = $cmd_event->{from_nick} // '';
            my $cmd  = $cmd_event->{command} // '';
            my $args = $cmd_event->{args} // '';

            $logger->debug("Command from $from: !$cmd $args");

            my $response = dispatch_command($from, $cmd, $args);
            if (defined $response) {
                $gateway->send_chat($nick, $response);
            }
        });
    };

    last unless $running;

    # event_stream returns when the connection drops
    $logger->warn("Event stream disconnected, reconnecting in ${reconnect_delay}s...");
    sleep($reconnect_delay);

    # Re-register on reconnect — gateway may have restarted, wiping the
    # in-memory bot registry and invalidating our token.
    unless (do_register()) {
        $logger->warn("Re-registration failed, will retry...");
    } else {
        $reconnect_delay = 2;  # reset backoff on successful re-register
    }

    $reconnect_delay = ($reconnect_delay * 2 > 60) ? 60 : $reconnect_delay * 2;
}

$logger->info("Main loop exited, shutting down");

# -----------------------------------------------------------------------
# Command dispatch
# -----------------------------------------------------------------------

sub dispatch_command {
    my ($from_nick, $cmd, $args) = @_;

    # Resolve alias
    $cmd = $aliases{$cmd} if exists $aliases{$cmd};

    # Look up command module
    my $module = $commands{$cmd};
    return undef unless $module;

    my $run = $module->can('run');
    my $response = eval { $run->($from_nick, $args, $gateway) };
    if ($@) {
        $logger->warn("Command $cmd error: $@");
        return "Error running !$cmd";
    }
    return $response;
}
