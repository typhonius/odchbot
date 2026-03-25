#!/usr/bin/perl

#--------------------------
# ODCHBot v4 - Entry Point for OpenDCHub
#
# This file is loaded by opendchub's embedded Perl interpreter.
# It exposes the named functions that opendchub expects:
#   main, data_arrival, hub_timer,
#   new_user_connected, reg_user_connected,
#   op_connected, op_admin_connected,
#   user_disconnected, attempted_connection
#--------------------------

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use ODCHBot::Core;
use ODCHBot::Adapter::NMDC;
use ODCHBot::User;
use ODCHBot::Context;
use Log::Log4perl qw(:easy);

# --- Global Bot Instance ---
my $BOT;
my $ADAPTER;

eval {
    $BOT = ODCHBot::Core->new(
        config_file => "$FindBin::Bin/../odchbot.yml",
    );

    $ADAPTER = ODCHBot::Adapter::NMDC->new(bot => $BOT);
    $BOT->adapter($ADAPTER);

    $ADAPTER->on_init;
};
if ($@) {
    eval { odch::data_to_all("<ODCHBot> FATAL: $@|") };
    die $@;
}

# --- OpenDCHub Callback Functions ---

sub main {
    eval { odch::register_script_name($BOT->bot_name) };

    my $topic = $BOT->config->get('topic') // '';
    if ($topic) {
        eval { odch::data_to_all("\$HubName $topic|") };
    }

    my $name = $BOT->bot_name;
    my $version = $ODCHBot::Core::VERSION;
    eval { odch::data_to_all("<$name> $name version $version loaded.|") };
    DEBUG "$name v$version started";
}

sub data_arrival {
    my ($name, $data) = @_;
    return unless $name && $data;

    $data =~ s/[\r\n]+/ /g;

    # Password (ignored but consumed)
    if ($data =~ /^\$MyPass\s/) {
        return;
    }
    # Search (just count it)
    elsif ($data =~ /^\$Search/) {
        return;
    }
    # Main chat: <Username> message|
    elsif ($data =~ /^\<\Q$name\E\>\s(.*)\|/) {
        my $chat = $1;
        $ADAPTER->on_main_chat($name, $chat);
    }
    # Private message: $To: target From: sender $<sender> message|
    elsif ($data =~ /^\$To:\s(\w+)\sFrom:\s\Q$name\E\s\$\<\Q$name\E\>\s(.*)\|/) {
        my ($to, $msg) = ($1, $2);
        $BOT->emit_hook('pm', user_name => $name, to => $to, message => $msg);
    }
}

sub attempted_connection {
    my ($hostname) = @_;
    # Reserved for IP-level blocking
}

sub new_user_connected {
    my ($name) = @_;
    _do_login($name, ODCHBot::User::PERM_ANONYMOUS);
}

sub reg_user_connected {
    my ($name) = @_;
    _do_login($name, ODCHBot::User::PERM_AUTHENTICATED);
}

sub op_connected {
    my ($name) = @_;
    _do_login($name, ODCHBot::User::PERM_OPERATOR);
}

sub op_admin_connected {
    my ($name) = @_;
    _do_login($name, ODCHBot::User::PERM_ADMINISTRATOR);
}

sub _do_login {
    my ($name, $permission) = @_;

    my $ip    = eval { odch::get_ip($name) }          // '';
    my $share = eval { odch::get_share($name) }        // 0;
    my $desc  = eval { odch::get_description($name) }  // '';

    $ADAPTER->on_post_login($name, $ip);
}

sub user_disconnected {
    my ($name) = @_;
    $ADAPTER->on_user_disconnect($name);
}

sub hub_timer {
    $ADAPTER->on_timer;
}

# Keep script alive for opendchub
exit 0;
