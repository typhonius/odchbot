#!/usr/bin/perl

#--------------------------
# Dragon (ODCHBot v4) — Standalone NMDC Client Bot
#
# Connects to the hub as a regular DC user.
# Appears in the user list. Calls Gateway API for data.
# Commands live in commands_v4/ as separate .pm modules.
#--------------------------

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/commands_v4";
use Log::Log4perl qw(:levels);

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

my $hub_config = $config->{hub} || {};
my $gw_config  = $config->{gateway} || {};
my $nick = $hub_config->{nick} || 'Dragon';

# -----------------------------------------------------------------------
# Initialize Gateway client
# -----------------------------------------------------------------------
my $gateway = GatewayClient->new(
    url     => $gw_config->{url} || 'http://127.0.0.1:3000',
    api_key => $gw_config->{bot_api_key} || '',
);

# -----------------------------------------------------------------------
# Load command modules from commands_v4/
# -----------------------------------------------------------------------
my %commands;    # name => module package
my %aliases;     # alias => name

my $cmd_dir = "$FindBin::Bin/commands_v4";
if (-d $cmd_dir) {
    opendir(my $dh, $cmd_dir) or $logger->warn("Cannot open $cmd_dir: $!");
    if ($dh) {
        for my $file (sort readdir $dh) {
            next unless $file =~ /^(\w+)\.pm$/;
            my $modname = "commands_v4::$1";
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

# Register with gateway — declare all commands Dragon handles
my @all_cmds = (keys %commands, keys %aliases);
$gateway->register($nick, @all_cmds);
$logger->info("Registered with gateway as $nick, claiming " . scalar(@all_cmds) . " commands");

# -----------------------------------------------------------------------
# Connect to hub
# -----------------------------------------------------------------------
my $client;

sub create_client {
    $client = NMDCClient->new(
        host        => $hub_config->{host} || '127.0.0.1',
        port        => $hub_config->{port} || 4012,
        nick        => $nick,
        password    => $hub_config->{password} || '',
        description => $hub_config->{description} || 'Hub Bot',
        email       => $hub_config->{email} || '',
        tag         => "<odchbot V:$VERSION>",
        speed       => 'LAN(T1)',

        on_chat => sub { handle_chat(@_) },
        on_pm   => sub { handle_pm(@_) },
        on_join => sub { handle_join(@_) },
        on_quit => sub { handle_quit(@_) },
    );
}

# -----------------------------------------------------------------------
# Main loop with reconnect
# -----------------------------------------------------------------------
my $reconnect_delay = 5;
create_client();

while (1) {
    if ($client->connect()) {
        $reconnect_delay = 5;
        $logger->info("Connected and logged in as $nick");

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
    create_client();
}

# -----------------------------------------------------------------------
# Event handlers
# -----------------------------------------------------------------------

sub handle_chat {
    my ($from_nick, $message) = @_;
    if ($message =~ /^!(\w+)\s*(.*)$/) {
        my ($cmd, $args) = (lc($1), $2 // '');
        my $response = dispatch_command($from_nick, $cmd, $args);
        $client->send_chat($response) if defined $response;
    }
}

sub handle_pm {
    my ($from_nick, $message) = @_;
    $logger->debug("PM from $from_nick: $message");
    if ($message =~ /^!(\w+)\s*(.*)$/) {
        my ($cmd, $args) = (lc($1), $2 // '');
        my $response = dispatch_command($from_nick, $cmd, $args);
        $client->send_pm($from_nick, $response) if defined $response;
    }
}

sub handle_join {
    my ($joined_nick) = @_;
    $logger->debug("User joined: $joined_nick");
    # Tell delivery and watcher notifications handled by gateway event processor
}

sub handle_quit {
    my ($quit_nick) = @_;
    $logger->debug("User quit: $quit_nick");
    # Watcher notifications handled by gateway event processor
}

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

    my $response = eval { $module->run($from_nick, $args, $client, $gateway) };
    if ($@) {
        $logger->warn("Command $cmd error: $@");
        return "Error running !$cmd";
    }
    return $response;
}
