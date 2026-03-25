#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use ODCHBot::User;

# Permission constants
is(ODCHBot::User::PERM_OFFLINE,       0,  'PERM_OFFLINE is 0');
is(ODCHBot::User::PERM_ANONYMOUS,     4,  'PERM_ANONYMOUS is 4');
is(ODCHBot::User::PERM_AUTHENTICATED, 8,  'PERM_AUTHENTICATED is 8');
is(ODCHBot::User::PERM_OPERATOR,      16, 'PERM_OPERATOR is 16');
is(ODCHBot::User::PERM_ADMINISTRATOR, 32, 'PERM_ADMINISTRATOR is 32');

# Basic construction
{
    my $user = ODCHBot::User->new(name => 'TestUser');
    is($user->name, 'TestUser', 'name set correctly');
    is($user->permission, ODCHBot::User::PERM_ANONYMOUS, 'default permission is anonymous');
    ok(!$user->is_online, 'new user is not online');
}

# permission_at_least
{
    my $op = ODCHBot::User->new(name => 'Op', permission => ODCHBot::User::PERM_OPERATOR);
    ok($op->permission_at_least(ODCHBot::User::PERM_ANONYMOUS), 'op outranks anonymous');
    ok($op->permission_at_least(ODCHBot::User::PERM_OPERATOR), 'op meets operator');
    ok(!$op->permission_at_least(ODCHBot::User::PERM_ADMINISTRATOR), 'op does not meet admin');
}

# outranks
{
    my $op = ODCHBot::User->new(name => 'Op', permission => ODCHBot::User::PERM_OPERATOR);
    my $user = ODCHBot::User->new(name => 'User', permission => ODCHBot::User::PERM_ANONYMOUS);
    ok($op->outranks($user), 'op outranks user');
    ok(!$user->outranks($op), 'user does not outrank op');
}

# is_online
{
    my $user = ODCHBot::User->new(name => 'Test', connect_time => time());
    ok($user->is_online, 'user with connect_time and no disconnect is online');

    $user->disconnect_time(time() + 1);
    ok(!$user->is_online, 'user with disconnect > connect is offline');
}

# permission_name
{
    my $admin = ODCHBot::User->new(name => 'A', permission => ODCHBot::User::PERM_ADMINISTRATOR);
    like($admin->permission_name, qr/Admin/i, 'admin permission name');

    my $anon = ODCHBot::User->new(name => 'B', permission => ODCHBot::User::PERM_ANONYMOUS);
    like($anon->permission_name, qr/Anon/i, 'anon permission name');
}

# online_duration
{
    my $user = ODCHBot::User->new(name => 'Test', connect_time => time() - 60);
    ok($user->online_duration >= 59, 'online_duration is roughly correct');
}

done_testing();
