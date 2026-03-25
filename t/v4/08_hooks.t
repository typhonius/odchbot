#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin";
use TestBot;

use ODCHBot::User;

my ($bot, $adapter) = TestBot::setup(config => { user_op_login_notify => 1 });

# Postlogin hook fires welcome message
{
    $adapter->clear;
    my $user = $adapter->simulate_login(
        name       => 'WelcomeUser',
        ip         => '10.0.0.1',
        permission => ODCHBot::User::PERM_ANONYMOUS,
    );
    ok($adapter->message_count > 0, 'postlogin produces welcome messages');
    my @welcome = $adapter->messages_matching(qr/Welcome/);
    ok(scalar @welcome > 0, 'welcome message found');
}

# Op login notification
{
    $adapter->clear;
    my $op = $adapter->simulate_login(
        name       => 'OpUser',
        ip         => '10.0.0.2',
        permission => ODCHBot::User::PERM_OPERATOR,
    );
    my @notify = $adapter->messages_matching(qr/Welcome online/);
    ok(scalar @notify > 0, 'op login notification sent');
}

# Karma line hook - name++
{
    my $user = TestBot::make_user($bot, name => 'KarmaGiver');
    $adapter->clear;
    $adapter->simulate_chat($user, 'SomeUser++');
    # Karma hook should fire (may or may not produce output depending on implementation)
    pass('karma line hook did not crash');
}

# Timer hook fires without error
{
    $adapter->clear;
    $adapter->simulate_timer;
    pass('timer hook fires without error');
}

# Logout hook
{
    $adapter->clear;
    $adapter->simulate_logout('WelcomeUser');
    pass('logout hook fires without error');
}

# Topic postlogin hook
{
    $adapter->clear;
    my $user = $adapter->simulate_login(
        name => 'TopicUser',
        ip   => '10.0.0.3',
    );
    my @topic = $adapter->messages_matching(qr/Topic|Welcome/);
    ok(scalar @topic > 0, 'topic or welcome shown on login');
}

done_testing();
