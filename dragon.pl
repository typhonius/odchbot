#!/usr/bin/perl

#--------------------------
# Dragon (ODCHBot v4) — Standalone NMDC Client
#
# Connects to the hub as a regular DC client.
# Appears in the user list. Calls Gateway API for data.
# Optional add-on for fun commands, external integrations, and plugins.
#--------------------------

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use Log::Log4perl qw(:levels);
use YAML::AppConfig;
use POSIX qw(strftime);

use NMDCClient;
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
my $logger = Log::Log4perl->get_logger('Dragon');
$logger->info("Dragon v$VERSION starting");

# -----------------------------------------------------------------------
# Load config
# -----------------------------------------------------------------------
my $config_file = "$FindBin::Bin/odchbot.yml";
die "Config not found: $config_file\n" unless -f $config_file;
my $app_config = YAML::AppConfig->new(file => $config_file);
my $config = $app_config->config();

my $hub_config = $config->{hub} || {};
my $gw_config  = $config->{gateway} || {};

# -----------------------------------------------------------------------
# Initialize Gateway client
# -----------------------------------------------------------------------
my $gateway = GatewayClient->new(
    url     => $gw_config->{url} || 'http://127.0.0.1:3000',
    api_key => $gw_config->{bot_api_key} || '',
);

# Register with gateway — only declare commands Dragon actually implements.
# Gateway's built-in commands (tell, ban, history, stats, etc.) stay active.
my $nick = $hub_config->{nick} || 'Dragon';
$gateway->register($nick, 'coin', 'roll', 'time', 'magic_8ball', '8ball',
                    'russianroulette', 'rr', 'lasercats');

$logger->info("Registered with gateway as $nick");

# -----------------------------------------------------------------------
# Load command modules
# -----------------------------------------------------------------------
my %commands;
my $cmd_path = $config->{config}{commandPath} || 'commands';
my $cmd_dir = "$FindBin::Bin/$cmd_path";

if (-d $cmd_dir) {
    opendir(my $dh, $cmd_dir) or $logger->warn("Cannot open $cmd_dir: $!");
    if ($dh) {
        for my $file (readdir $dh) {
            next unless $file =~ /^(\w+)\.pm$/;
            my $name = $1;
            eval {
                require "$cmd_dir/$file";
                $commands{$name} = 1;
                $logger->debug("Loaded command: $name");
            };
            if ($@) {
                $logger->warn("Failed to load command $name: $@");
            }
        }
        closedir $dh;
    }
}
$logger->info("Loaded " . scalar(keys %commands) . " command modules");

# -----------------------------------------------------------------------
# Connect to hub
# -----------------------------------------------------------------------
my $client = NMDCClient->new(
    host        => $hub_config->{host} || '127.0.0.1',
    port        => $hub_config->{port} || 4012,
    nick        => $nick,
    password    => $hub_config->{password} || '',
    description => $hub_config->{description} || 'Hub Bot',
    email       => $hub_config->{email} || '',
    tag         => "<odchbot V:$VERSION>",
    speed       => 'LAN(T1)',

    on_chat => sub {
        my ($from_nick, $message) = @_;
        handle_chat($from_nick, $message);
    },

    on_pm => sub {
        my ($from_nick, $message) = @_;
        handle_pm($from_nick, $message);
    },

    on_join => sub {
        my ($joined_nick) = @_;
        handle_join($joined_nick);
    },

    on_quit => sub {
        my ($quit_nick) = @_;
        handle_quit($quit_nick);
    },
);

# -----------------------------------------------------------------------
# Main loop with reconnect
# -----------------------------------------------------------------------
my $reconnect_delay = 5;

while (1) {
    if ($client->connect()) {
        $reconnect_delay = 5;
        $logger->info("Connected and logged in as $nick");

        # Main event loop
        while ($client->is_connected()) {
            $client->poll(500);
        }

        $logger->warn("Disconnected from hub");
    } else {
        $logger->error("Failed to connect to hub");
    }

    $logger->info("Reconnecting in ${reconnect_delay}s...");
    sleep($reconnect_delay);
    $reconnect_delay = ($reconnect_delay * 2 > 300) ? 300 : $reconnect_delay * 2;
}

# -----------------------------------------------------------------------
# Event handlers
# -----------------------------------------------------------------------

sub handle_chat {
    my ($from_nick, $message) = @_;

    # Check for command prefix
    if ($message =~ /^!(\w+)\s*(.*)$/) {
        my ($cmd, $args) = ($1, $2 // '');
        handle_command($from_nick, lc($cmd), $args);
    }
}

sub handle_pm {
    my ($from_nick, $message) = @_;
    # Dragon could handle PM commands here
    $logger->debug("PM from $from_nick: $message");
}

sub handle_join {
    my ($joined_nick) = @_;
    $logger->debug("User joined: $joined_nick");

    # Deliver pending tells
    eval {
        my $tells = $gateway->get_pending_tells($joined_nick);
        for my $tell (@$tells) {
            my $from = $tell->{from_nick};
            my $msg  = $tell->{message};
            my $when = $tell->{created_at} || 'sometime';
            $client->send_pm($joined_nick,
                "Tell from $from ($when): $msg");
            $gateway->mark_tell_delivered($tell->{id});
        }
    };
    $logger->warn("Tell delivery error: $@") if $@;

    # Notify watchers
    eval {
        my $watchers = $gateway->get_watchers($joined_nick);
        for my $w (@$watchers) {
            $client->send_pm($w->{watcher_nick},
                "$joined_nick has logged in.");
        }
    };
}

sub handle_quit {
    my ($quit_nick) = @_;
    $logger->debug("User quit: $quit_nick");

    # Notify watchers
    eval {
        my $watchers = $gateway->get_watchers($quit_nick);
        for my $w (@$watchers) {
            $client->send_pm($w->{watcher_nick},
                "$quit_nick has logged out.");
        }
    };
}

sub handle_command {
    my ($from_nick, $cmd, $args) = @_;

    # Built-in Dragon commands (fun, external, personality)
    if ($cmd eq 'coin') {
        my @options = ('Heads!', 'Tails!');
        $client->send_chat($options[int(rand(2))]);
    }
    elsif ($cmd eq 'roll') {
        my ($count, $sides) = ($args =~ /^(\d+)?d(\d+)$/i);
        $count ||= 1; $sides ||= 6;
        $count = 10 if $count > 10;
        $sides = 1000 if $sides > 1000;
        my @rolls = map { int(rand($sides)) + 1 } 1..$count;
        my $total = 0; $total += $_ for @rolls;
        $client->send_chat(sprintf("%s rolled %dd%d: %s (total: %d)",
            $from_nick, $count, $sides, join(', ', @rolls), $total));
    }
    elsif ($cmd eq 'time') {
        $client->send_chat(strftime("Current time: %Y-%m-%d %H:%M:%S UTC", gmtime));
    }
    elsif ($cmd eq 'magic_8ball' || $cmd eq '8ball') {
        my @answers = (
            "It is certain.", "It is decidedly so.", "Without a doubt.",
            "Yes definitely.", "You may rely on it.", "As I see it, yes.",
            "Most likely.", "Outlook good.", "Yes.", "Signs point to yes.",
            "Reply hazy, try again.", "Ask again later.",
            "Better not tell you now.", "Cannot predict now.",
            "Concentrate and ask again.", "Don't count on it.",
            "My reply is no.", "My sources say no.",
            "Outlook not so good.", "Very doubtful.",
        );
        $client->send_chat($answers[int(rand(scalar @answers))]);
    }
    elsif ($cmd eq 'russianroulette' || $cmd eq 'rr') {
        if (int(rand(6)) == 0) {
            $client->send_chat("*BANG* $from_nick is dead!");
        } else {
            $client->send_chat("*click* $from_nick survives!");
        }
    }
    elsif ($cmd eq 'lasercats') {
        $client->send_chat('  /\_/\  PEW PEW PEW');
        $client->send_chat(' ( o.o ) ----=======');
        $client->send_chat('  > ^ <');
    }
    else {
        # Unknown command — Dragon doesn't handle it
        # (Gateway built-in commands will catch it instead)
        $logger->debug("Unknown Dragon command: $cmd");
    }
}
