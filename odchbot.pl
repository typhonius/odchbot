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

# -----------------------------------------------------------------------
# PID file — prevent duplicate instances
# -----------------------------------------------------------------------
my $pidfile = "$FindBin::Bin/dragon.pid";
if (-f $pidfile) {
    open my $fh, '<', $pidfile;
    my $old_pid = <$fh>;
    close $fh;
    chomp($old_pid) if $old_pid;
    if ($old_pid && kill(0, $old_pid)) {
        $logger->fatal("Another instance is already running (PID $old_pid). Exiting.");
        die "Another instance is already running (PID $old_pid)\n";
    }
}
open my $pidfh, '>', $pidfile or die "Cannot write $pidfile: $!";
print $pidfh $$;
close $pidfh;

$logger->info("Dragon v$VERSION starting (PID $$)");

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
# Register with gateway — declare bot identity, commands, and event subs
# -----------------------------------------------------------------------
my @all_cmds = (keys %commands, keys %aliases);
my @event_subs = qw(command pm chat user_join user_quit user_info kick ban unban gag ungag
                     hub_name op_list gateway_status maintenance_tick);

sub do_register {
    my $result = $gateway->register(
        nick        => $nick,
        description => $description,
        email       => $email,
        tag         => $tag,
        commands    => \@all_cmds,
        events      => \@event_subs,
    );
    if ($result && $result->{token}) {
        $logger->info("Registered with gateway as $nick, claiming "
            . scalar(@all_cmds) . " commands, "
            . scalar(@event_subs) . " event subscriptions");
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
    unlink $pidfile if defined $pidfile;
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

            if ($event_type eq 'command') {
                my $from = $event_data->{from_nick} // '';
                my $cmd  = $event_data->{command} // '';
                my $args = $event_data->{args} // '';

                $logger->debug("Command from $from: !$cmd $args");

                my $response = dispatch_command($from, $cmd, $args);
                if (defined $response) {
                    $gateway->send_chat($nick, $response);
                }
            }
            elsif ($event_type eq 'pm') {
                my $from = $event_data->{from_nick} // '';
                my $msg  = $event_data->{message} // '';
                $logger->debug("PM from $from: $msg");
            }
            elsif ($event_type eq 'chat') {
                my $who = $event_data->{nick} // '';
                my $msg = $event_data->{message} // '';
                $logger->trace("Chat <$who> $msg");
            }
            elsif ($event_type eq 'user_join') {
                my $who = $event_data->{nick} // return;
                $logger->info("User joined: $who");
                my $user = $gateway->get_user($who);
                if ($user && ($user->{permission} // 0) >= 3) {
                    $gateway->send_chat($nick, "All hail $who!");
                } else {
                    $gateway->send_chat($nick, "Welcome to the hub, $who!");
                }
            }
            elsif ($event_type eq 'user_quit') {
                my $who = $event_data->{nick} // return;
                $logger->info("User quit: $who");
            }
            elsif ($event_type eq 'user_info') {
                my $who   = $event_data->{nick} // '';
                my $share = $event_data->{share} // 0;
                $logger->trace("UserInfo update: $who (share: $share)");
            }
            elsif ($event_type eq 'kick') {
                my $who = $event_data->{nick} // '';
                my $by  = $event_data->{by} // '';
                $logger->info("$who was kicked by $by");
            }
            elsif ($event_type eq 'ban') {
                my $who    = $event_data->{nick} // '';
                my $by     = $event_data->{by} // '';
                my $reason = $event_data->{reason} // '';
                $logger->info("$who was banned by $by: $reason");
            }
            elsif ($event_type eq 'unban') {
                my $who = $event_data->{nick} // '';
                my $by  = $event_data->{by} // '';
                $logger->info("$who was unbanned by $by");
            }
            elsif ($event_type eq 'gag') {
                my $who    = $event_data->{nick} // '';
                my $by     = $event_data->{by} // '';
                my $reason = $event_data->{reason} // '';
                $logger->info("$who was gagged by $by: $reason");
            }
            elsif ($event_type eq 'ungag') {
                my $who = $event_data->{nick} // '';
                my $by  = $event_data->{by} // '';
                $logger->info("$who was ungagged by $by");
            }
            elsif ($event_type eq 'hub_name') {
                my $name = $event_data->{name} // '';
                $logger->info("Hub name changed to: $name");
            }
            elsif ($event_type eq 'op_list') {
                my $ops = $event_data->{ops} // [];
                $logger->debug("Op list updated: " . join(', ', @$ops));
            }
            elsif ($event_type eq 'gateway_status') {
                my $connected = $event_data->{connected} // 0;
                my $msg       = $event_data->{message} // '';
                if ($connected) {
                    $logger->info("Gateway connected: $msg");
                    $gateway->send_chat($nick, "I'm back! Gateway reconnected.");
                } else {
                    $logger->warn("Gateway disconnected: $msg");
                }
            }
            elsif ($event_type eq 'maintenance_tick') {
                $logger->trace("Maintenance tick");
            }
            elsif ($event_type eq 'error') {
                $logger->warn("SSE error: " . ($event_data->{message} // 'unknown'));
            }
            else {
                $logger->trace("Event: $event_type");
            }
        });
    };

    last unless $running;

    # event_stream returns when the connection drops
    $logger->warn("Event stream disconnected, reconnecting in ${reconnect_delay}s...");
    sleep($reconnect_delay);

    # Re-register on reconnect — gateway may have restarted, wiping the
    # in-memory bot registry and invalidating our token.
    if (do_register()) {
        $reconnect_delay = 2;  # reset backoff on successful re-register
    } else {
        $logger->warn("Re-registration failed, will retry...");
        $reconnect_delay = ($reconnect_delay * 2 > 60) ? 60 : $reconnect_delay * 2;
    }
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
