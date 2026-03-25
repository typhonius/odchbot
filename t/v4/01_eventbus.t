#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

use ODCHBot::EventBus;

# Basic emit/on
{
    my $bus = ODCHBot::EventBus->new;
    my $called = 0;
    $bus->on('test', sub { $called++ });
    $bus->emit('test');
    is($called, 1, 'listener is called on emit');
}

# Multiple listeners
{
    my $bus = ODCHBot::EventBus->new;
    my @order;
    $bus->on('test', sub { push @order, 'a' }, label => 'a', priority => 10);
    $bus->on('test', sub { push @order, 'b' }, label => 'b', priority => 5);
    $bus->emit('test');
    is_deeply(\@order, ['b', 'a'], 'listeners fire in priority order (lower first)');
}

# Off removes listener
{
    my $bus = ODCHBot::EventBus->new;
    my $called = 0;
    $bus->on('test', sub { $called++ }, label => 'remove_me');
    $bus->off('test', 'remove_me');
    $bus->emit('test');
    is($called, 0, 'removed listener is not called');
}

# Data passed to listeners
{
    my $bus = ODCHBot::EventBus->new;
    my $received;
    $bus->on('test', sub { $received = $_[0]->{value} });
    $bus->emit('test', { value => 42 });
    is($received, 42, 'data is passed to listener');
}

# Return values collected
{
    my $bus = ODCHBot::EventBus->new;
    $bus->on('test', sub { return 'hello' });
    $bus->on('test', sub { return 'world' });
    my $results = $bus->emit('test');
    is_deeply($results, ['hello', 'world'], 'emit returns listener results');
}

# Stop propagation
{
    my $bus = ODCHBot::EventBus->new;
    my $second_called = 0;
    $bus->on('test', sub { $_[0]->{_stop_propagation} = 1; return 'first' }, priority => 1);
    $bus->on('test', sub { $second_called++; return 'second' }, priority => 10);
    $bus->emit('test');
    is($second_called, 0, 'stop_propagation prevents later listeners');
}

# Error isolation
{
    my $bus = ODCHBot::EventBus->new(logger => sub {});
    my $called = 0;
    $bus->on('test', sub { die "boom" }, label => 'bad', priority => 1);
    $bus->on('test', sub { $called++ }, label => 'good', priority => 10);
    $bus->emit('test');
    is($called, 1, 'error in one listener does not block others');
}

# Clear
{
    my $bus = ODCHBot::EventBus->new;
    $bus->on('test', sub { 1 });
    $bus->clear;
    is(scalar $bus->listeners_for('test'), 0, 'clear removes all listeners');
}

done_testing();
