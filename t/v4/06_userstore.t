#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin";
use TestBot;

use ODCHBot::User;

my ($bot, $adapter) = TestBot::setup();

# Connect new user
{
    my ($user, $is_new) = $bot->users->connect_user(name => 'NewUser', ip => '10.0.0.1');
    ok($is_new, 'first connection is new');
    isa_ok($user, 'ODCHBot::User');
    is($user->name, 'NewUser', 'name correct');
    is($user->ip, '10.0.0.1', 'ip correct');
    ok($user->uid, 'uid assigned');
}

# Find by name
{
    my $found = $bot->users->find_by_name('NewUser');
    is($found->name, 'NewUser', 'find_by_name works');
}

# Connect existing user
{
    my ($user, $is_new) = $bot->users->connect_user(name => 'NewUser', ip => '10.0.0.2');
    ok(!$is_new, 'second connection is not new');
    is($user->ip, '10.0.0.2', 'ip updated');
}

# Online tracking
{
    ok($bot->users->is_online('NewUser'), 'user is online');
    is($bot->users->online_count, 1, 'one user online');

    my @online = $bot->users->online_users;
    is(scalar @online, 1, 'online_users returns one');
}

# Disconnect
{
    my $user = $bot->users->disconnect_user('NewUser');
    is($user->name, 'NewUser', 'disconnect returns user');
    ok(!$bot->users->is_online('NewUser'), 'user offline after disconnect');
    is($bot->users->online_count, 0, 'zero online');
}

# Find still works after disconnect (from DB)
{
    my $found = $bot->users->find_by_name('NewUser');
    is($found->name, 'NewUser', 'find_by_name works from DB after disconnect');
}

# Multiple users
{
    $bot->users->connect_user(name => 'User1');
    $bot->users->connect_user(name => 'User2');
    $bot->users->connect_user(name => 'User3');
    is($bot->users->online_count, 3, 'three users online');

    $bot->users->disconnect_user('User2');
    is($bot->users->online_count, 2, 'two after disconnect');
}

done_testing();
