#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin";
use TestBot;

use ODCHBot::User;

my ($bot, $adapter) = TestBot::setup();

# Kick command - needs operator
{
    my $op = TestBot::make_user($bot, name => 'OpKicker', permission => ODCHBot::User::PERM_OPERATOR);
    my $victim = TestBot::make_user($bot, name => 'Victim');
    $adapter->clear;

    $adapter->simulate_chat($op, '-kick Victim Bad behavior');
    my @kicks = grep { $_->{action} && $_->{action} eq 'kick' } @{ $adapter->actions };
    ok(scalar @kicks > 0, 'kick action fired');
    is($kicks[0]->{target}, 'Victim', 'correct kick target');
}

# Ban command
{
    my $op = TestBot::make_user($bot, name => 'BanOp', permission => ODCHBot::User::PERM_OPERATOR);
    my $target = TestBot::make_user($bot, name => 'BanTarget');
    $adapter->clear;

    $adapter->simulate_chat($op, '-ban BanTarget 5m test');
    ok($adapter->message_count > 0, 'ban produces output');
    like($adapter->last_message->{message}, qr/ban/i, 'ban confirmation');
}

# Gag command
{
    my $op = TestBot::make_user($bot, name => 'GagOp', permission => ODCHBot::User::PERM_OPERATOR);
    my $target = TestBot::make_user($bot, name => 'GagTarget');
    $adapter->clear;

    $adapter->simulate_chat($op, '-gag GagTarget');
    my @gags = grep { $_->{action} && $_->{action} eq 'gag' } @{ $adapter->actions };
    ok(scalar @gags > 0, 'gag action fired');
}

# Ungag
{
    my $op = TestBot::make_user($bot, name => 'UngagOp', permission => ODCHBot::User::PERM_OPERATOR);
    $adapter->clear;
    $adapter->simulate_chat($op, '-ungag GagTarget');
    my @ungags = grep { $_->{action} && $_->{action} eq 'ungag' } @{ $adapter->actions };
    ok(scalar @ungags > 0, 'ungag action fired');
}

# Config command - needs admin
{
    my $admin = TestBot::make_user($bot, name => 'AdminConfig', permission => ODCHBot::User::PERM_ADMINISTRATOR);
    $adapter->clear;

    $adapter->simulate_chat($admin, '-config get botname');
    like($adapter->last_message->{message}, qr/TestBot/, 'config get shows botname');

    $adapter->clear;
    $adapter->simulate_chat($admin, '-config set test_key test_value');
    like($adapter->last_message->{message}, qr/test_key|set/i, 'config set confirms');
    is($bot->config->get('test_key'), 'test_value', 'value actually set');
}

# Toggle command
{
    my $op = TestBot::make_user($bot, name => 'ToggleOp', permission => ODCHBot::User::PERM_OPERATOR);
    $adapter->clear;

    $adapter->simulate_chat($op, '-toggle coin');
    like($adapter->last_message->{message}, qr/disabled/, 'toggle disables coin');
    ok($bot->commands->is_disabled('coin'), 'coin is now disabled');

    $adapter->clear;
    $adapter->simulate_chat($op, '-toggle coin');
    like($adapter->last_message->{message}, qr/enabled/, 'toggle re-enables coin');
    ok(!$bot->commands->is_disabled('coin'), 'coin is now enabled');
}

# MassMessage
{
    my $op = TestBot::make_user($bot, name => 'MassOp', permission => ODCHBot::User::PERM_OPERATOR);
    $adapter->clear;
    $adapter->simulate_chat($op, '-massmessage Hello everyone');
    my @mass = grep { $_->{type} == ODCHBot::Context::MASS_MESSAGE() } @{ $adapter->messages };
    ok(scalar @mass > 0, 'mass message sent');
}

# Help command (no permission needed)
{
    my $user = TestBot::make_user($bot, name => 'HelpUser');
    $adapter->clear;
    $adapter->simulate_chat($user, '-help');
    ok($adapter->message_count > 0, 'help produces output');
}

done_testing();
