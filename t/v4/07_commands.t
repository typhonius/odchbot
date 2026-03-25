#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin";
use TestBot;

use ODCHBot::User;
use ODCHBot::Context;

my ($bot, $adapter) = TestBot::setup();

# Command discovery loaded commands
{
    my @names = $bot->commands->names;
    ok(scalar @names > 20, "loaded many commands (got " . scalar(@names) . ")");
    ok((grep { $_ eq 'coin' } @names), 'coin command loaded');
    ok((grep { $_ eq 'time' } @names), 'time command loaded');
    ok((grep { $_ eq 'help' } @names), 'help command loaded');
    ok((grep { $_ eq 'ban' } @names), 'ban command loaded');
}

# Command find by name and alias
{
    my $coin = $bot->commands->find('coin');
    ok($coin, 'find coin by name');
    is($coin->name, 'coin', 'correct command');

    my $mm = $bot->commands->find('mm');
    ok($mm, 'find massmessage by alias mm');
    is($mm->name, 'massmessage', 'alias resolves to massmessage');

    my $rr = $bot->commands->find('rr');
    ok($rr, 'find russianroulette by alias rr');
    is($rr->name, 'russianroulette', 'alias resolves');
}

# Command dispatch
{
    my $user = TestBot::make_user($bot, name => 'CmdUser');
    $adapter->clear;

    $adapter->simulate_chat($user, '-coin');
    ok($adapter->message_count > 0, 'coin command produces output');
    my $msg = $adapter->last_message;
    like($msg->{message}, qr/heads|tails|flip|coin/i, 'coin output looks right');
}

# Time command
{
    my $user = TestBot::make_user($bot, name => 'TimeUser');
    $adapter->clear;

    $adapter->simulate_chat($user, '-time');
    ok($adapter->message_count > 0, 'time command produces output');
    like($adapter->last_message->{message}, qr/\d{4}/, 'time output contains year');
}

# Commands command (list)
{
    my $user = TestBot::make_user($bot, name => 'ListUser');
    $adapter->clear;

    $adapter->simulate_chat($user, '-commands');
    ok($adapter->message_count > 0, 'commands command produces output');
    like($adapter->last_message->{message}, qr/coin|time|help/i, 'commands lists some commands');
}

# Permission check
{
    my $user = TestBot::make_user($bot, name => 'NoPerm', permission => ODCHBot::User::PERM_ANONYMOUS);
    $adapter->clear;

    $adapter->simulate_chat($user, '-kick SomeUser');
    ok($adapter->message_count > 0, 'denied command produces output');
    like($adapter->last_message->{message}, qr/permission/i, 'permission denied message');
}

# Disable/enable
{
    $bot->commands->disable('coin');
    ok($bot->commands->is_disabled('coin'), 'coin is disabled');

    my $user = TestBot::make_user($bot, name => 'ToggleUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-coin');
    like($adapter->last_message->{message}, qr/disabled/i, 'disabled command reports status');

    $bot->commands->enable('coin');
    ok(!$bot->commands->is_disabled('coin'), 'coin re-enabled');
}

# MyNick command
{
    my $user = TestBot::make_user($bot, name => 'NickUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-mynick');
    like($adapter->last_message->{message}, qr/NickUser/, 'mynick shows username');
}

# Roll command
{
    my $user = TestBot::make_user($bot, name => 'RollUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-roll 2d6');
    ok($adapter->message_count > 0, 'roll produces output');
    like($adapter->last_message->{message}, qr/\d/, 'roll output contains a number');
}

# Google command
{
    my $user = TestBot::make_user($bot, name => 'GoogleUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-google test query');
    like($adapter->last_message->{message}, qr/google.*test/i, 'google produces search link');
}

# Rules command
{
    my $user = TestBot::make_user($bot, name => 'RulesUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-rules');
    like($adapter->last_message->{message}, qr/example\.com\/rules/, 'rules shows URL');
}

# Uptime command
{
    my $user = TestBot::make_user($bot, name => 'UptimeUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-uptime');
    like($adapter->last_message->{message}, qr/uptime|second|minute/i, 'uptime shows duration');
}

# Unknown command
{
    my $user = TestBot::make_user($bot, name => 'UnkUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-nonexistentcommand');
    is($adapter->message_count, 0, 'unknown command produces no output');
}

# Random command
{
    my $user = TestBot::make_user($bot, name => 'RandUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-random');
    ok($adapter->message_count > 0, 'random produces output');
    like($adapter->last_message->{message}, qr/The \w+/, 'random produces sentence');
}

# MagicEightBall (alias 8ball)
{
    my $user = TestBot::make_user($bot, name => 'M8BUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-8ball Will this work?');
    ok($adapter->message_count > 0, '8ball produces output');
}

# History - line hook records, command retrieves
{
    my $user = TestBot::make_user($bot, name => 'HistUser');
    $adapter->clear;
    $adapter->simulate_chat($user, 'Hello world this is a test message');
    $adapter->clear;
    $adapter->simulate_chat($user, '-history');
    ok($adapter->message_count > 0, 'history produces output');
}

# Tell command
{
    my $user = TestBot::make_user($bot, name => 'TellSender');
    $adapter->clear;
    $adapter->simulate_chat($user, '-tell OfflineUser Hey check this out');
    ok($adapter->message_count > 0, 'tell produces confirmation');
    like($adapter->last_message->{message}, qr/OfflineUser|message|saved/i, 'tell confirms');
}

# Search command (needs content)
{
    my $user = TestBot::make_user($bot, name => 'SearchUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-search hello');
    ok($adapter->message_count > 0, 'search produces output');
}

# Haha command (probabilistic - just test it runs)
{
    my $user = TestBot::make_user($bot, name => 'HahaUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-haha');
    ok($adapter->message_count > 0, 'haha produces output');
}

# Info command
{
    my $target = TestBot::make_user($bot, name => 'InfoTarget');
    my $user = TestBot::make_user($bot, name => 'InfoUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-info InfoTarget');
    ok($adapter->message_count > 0, 'info produces output');
    like($adapter->last_message->{message}, qr/InfoTarget/, 'info shows target name');
}

# Seen command
{
    my $user = TestBot::make_user($bot, name => 'SeenUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-seen InfoTarget');
    ok($adapter->message_count > 0, 'seen produces output');
}

# TV command (stub)
{
    my $user = TestBot::make_user($bot, name => 'TVUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-tv');
    ok($adapter->message_count > 0, 'tv produces output');
}

done_testing();
