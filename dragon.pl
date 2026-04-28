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

# Register with gateway — discover commands from handle_command dispatch
# plus any loaded command modules. Gateway disables its built-in handlers
# for commands Dragon claims.
my $nick = $hub_config->{nick} || 'Dragon';

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

# Auto-discover commands: built-in handlers + loaded command modules
my @dragon_commands = ('coin', 'roll', 'time', 'magic_8ball', '8ball',
                       'russianroulette', 'rr', 'lasercats');
push @dragon_commands, keys %commands;
$gateway->register($nick, @dragon_commands);
$logger->info("Registered with gateway as $nick, claiming " . scalar(@dragon_commands) . " commands");

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
        my $response = handle_command_response($from_nick, lc($cmd), $args);
        if ($response) {
            $client->send_chat($response);
        }
    }
}

sub handle_pm {
    my ($from_nick, $message) = @_;
    $logger->debug("PM from $from_nick: $message");

    # Handle commands via PM (same as chat but reply via PM)
    if ($message =~ /^!(\w+)\s*(.*)$/) {
        my ($cmd, $args) = ($1, $2 // '');
        my $response = handle_command_response($from_nick, lc($cmd), $args);
        if ($response) {
            $client->send_pm($from_nick, $response);
        }
    }
}

sub handle_join {
    my ($joined_nick) = @_;
    $logger->debug("User joined: $joined_nick");
    # Tell delivery and watcher notifications are handled by the gateway
    # event processor — Dragon doesn't need to do anything here.
}

sub handle_quit {
    my ($quit_nick) = @_;
    $logger->debug("User quit: $quit_nick");
    # Watcher notifications handled by gateway event processor.
}

sub handle_command_response {
    my ($from_nick, $cmd, $args) = @_;

    # Built-in Dragon commands (fun, external, personality)
    # Returns response string, or undef if not a Dragon command.
    if ($cmd eq 'coin') {
        my @options = ('Heads!', 'Tails!');
        return $options[int(rand(2))];
    }
    elsif ($cmd eq 'roll') {
        my ($count, $sides) = ($args =~ /^(\d+)?d(\d+)$/i);
        $count ||= 1; $sides ||= 6;
        $count = 10 if $count > 10;
        $sides = 1000 if $sides > 1000;
        my @rolls = map { int(rand($sides)) + 1 } 1..$count;
        my $total = 0; $total += $_ for @rolls;
        return sprintf("%s rolled %dd%d: %s (total: %d)",
            $from_nick, $count, $sides, join(', ', @rolls), $total);
    }
    elsif ($cmd eq 'time') {
        return strftime("Current time: %Y-%m-%d %H:%M:%S UTC", gmtime);
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
        return $answers[int(rand(scalar @answers))];
    }
    elsif ($cmd eq 'russianroulette' || $cmd eq 'rr') {
        if (int(rand(6)) == 0) {
            $client->send_chat("*BANG* $from_nick is dead!");
            # Kick the user (via gateway API moderation endpoint)
            eval {
                my $ua = $gateway->{ua};
                my $url = "$gateway->{base_url}/api/v1/users/$from_nick/kick";
                my $req = HTTP::Request->new(POST => $url);
                $req->header('Content-Type' => 'application/json');
                $req->header('X-API-Key' => $gateway->{api_key});
                $req->content('{"reason":"Russian roulette"}');
                $ua->request($req);
            };
            return undef; # already sent chat
        } else {
            return "*click* $from_nick survives!";
        }
    }
    elsif ($cmd eq 'lasercats') {
        $client->send_chat('  /\_/\  PEW PEW PEW');
        $client->send_chat(' ( o.o ) ----=======');
        $client->send_chat('  > ^ <');
        # Kick the invoker (lasercats tradition!)
        eval {
            my $ua = $gateway->{ua};
            my $url = "$gateway->{base_url}/api/v1/users/$from_nick/kick";
            my $req = HTTP::Request->new(POST => $url);
            $req->header('Content-Type' => 'application/json');
            $req->header('X-API-Key' => $gateway->{api_key});
            $req->content('{"reason":"LASERCATS PEW PEW PEW"}');
            $ua->request($req);
        };
        return undef; # already sent chat
    }
    else {
        $logger->debug("Unknown Dragon command: $cmd");
        return undef;
    }
}
