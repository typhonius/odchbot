#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

my @modules = qw(
    ODCHBot::EventBus
    ODCHBot::Config
    ODCHBot::Database
    ODCHBot::User
    ODCHBot::UserStore
    ODCHBot::Context
    ODCHBot::Formatter
    ODCHBot::CommandRegistry
    ODCHBot::Core
    ODCHBot::Role::Command
    ODCHBot::Role::Adapter
    ODCHBot::Adapter::NMDC
    ODCHBot::Adapter::Test
);

plan tests => scalar @modules;

for my $module (@modules) {
    use_ok($module);
}

done_testing();
