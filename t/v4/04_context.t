#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin";
use TestBot;
use ODCHBot::Context;

my ($bot, $adapter) = TestBot::setup();

# Basic construction
{
    my $user = TestBot::make_user($bot, name => 'Alice');
    my $ctx = ODCHBot::Context->new(bot => $bot, user => $user, text => 'hello world');
    is($ctx->args, 'hello world', 'args returns text');
    is($ctx->user->name, 'Alice', 'user accessible');
    ok(!$ctx->has_responses, 'no responses initially');
}

# Reply methods
{
    my $user = TestBot::make_user($bot, name => 'Bob');
    my $ctx = ODCHBot::Context->new(bot => $bot, user => $user);

    $ctx->reply('private message');
    $ctx->reply_public('public message');
    $ctx->reply_hub('hub message');

    ok($ctx->has_responses, 'has responses after replies');
    my @r = $ctx->responses;
    is(scalar @r, 3, 'three responses');
    is($r[0]->{type}, ODCHBot::Context::PUBLIC_SINGLE, 'reply is PUBLIC_SINGLE');
    is($r[1]->{type}, ODCHBot::Context::PUBLIC_ALL, 'reply_public is PUBLIC_ALL');
    is($r[2]->{type}, ODCHBot::Context::HUB_PUBLIC, 'reply_hub is HUB_PUBLIC');
}

# Fluent chaining
{
    my $user = TestBot::make_user($bot, name => 'Carol');
    my $ctx = ODCHBot::Context->new(bot => $bot, user => $user);
    my $result = $ctx->reply('a')->reply_public('b')->reply_hub('c');
    is($result, $ctx, 'methods return $self for chaining');
    is(scalar($ctx->responses), 3, 'chained responses all recorded');
}

# Action responses
{
    my $user = TestBot::make_user($bot, name => 'Dave');
    my $ctx = ODCHBot::Context->new(bot => $bot, user => $user);

    $ctx->kick($user, 'test kick');
    $ctx->ban('EvilUser', 'banned');
    $ctx->gag('LoudUser');

    my @r = $ctx->responses;
    is($r[0]->{action}, 'kick', 'kick action');
    is($r[0]->{target}, 'Dave', 'kick target');
    is($r[1]->{action}, 'nickban', 'ban action');
    is($r[2]->{action}, 'gag', 'gag action');
}

# Spoof
{
    my $user = TestBot::make_user($bot, name => 'Eve');
    my $ctx = ODCHBot::Context->new(bot => $bot, user => $user);
    $ctx->spoof_public('FakeName', 'spoofed message');
    my @r = $ctx->responses;
    is($r[0]->{type}, ODCHBot::Context::SPOOF_PUBLIC, 'spoof type');
    is($r[0]->{user}, 'FakeName', 'spoof user is the fake name');
}

# Convenience accessors
{
    my $user = TestBot::make_user($bot, name => 'Frank');
    my $ctx = ODCHBot::Context->new(bot => $bot, user => $user);
    isa_ok($ctx->config, 'ODCHBot::Config');
    isa_ok($ctx->db, 'ODCHBot::Database');
    isa_ok($ctx->users, 'ODCHBot::UserStore');
    isa_ok($ctx->bus, 'ODCHBot::EventBus');
}

done_testing();
