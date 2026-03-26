#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

# Set up minimal config needed by DCBCommon (and its dependency chain)
use DCBSettings;
$DCBSettings::config = {
    timezone    => 'UTC',
    commandPath => 'commands',
    db => {
        driver   => 'SQLite',
        database => ':memory:',
        path     => '',
        username => '',
        password => '',
    },
    botname            => 'TestBot',
    botemail           => 'test@test.com',
    username_anonymous => 'Anonymous',
    username_max_length => 30,
};
$DCBSettings::cwd = '';

# Load DCBCommon with constants exported
use DCBCommon;

ok(1, 'DCBCommon loaded successfully');

# Test MESSAGE constants
is(MESSAGE->{HUB_PUBLIC}, 1, 'HUB_PUBLIC is 1');
is(MESSAGE->{PUBLIC_SINGLE}, 2, 'PUBLIC_SINGLE is 2');
is(MESSAGE->{BOT_PM}, 3, 'BOT_PM is 3');
is(MESSAGE->{PUBLIC_ALL}, 4, 'PUBLIC_ALL is 4');
is(MESSAGE->{RAW}, 11, 'RAW is 11');
is(MESSAGE->{SEND_TO_ADMINS}, 12, 'SEND_TO_ADMINS is 12');

# Test common_timestamp_time
my $timestamp = DCBCommon::common_timestamp_time(0);
is($timestamp, '1970-01-01 00:00:00', 'epoch 0 formats correctly in UTC');

my $timestamp2 = DCBCommon::common_timestamp_time(1000000000);
is($timestamp2, '2001-09-09 01:46:40', 'epoch 1000000000 formats correctly');

# Test common_format_size
my $size = DCBCommon::common_format_size(1024);
ok($size =~ /1.*K/i, 'formats 1024 bytes as ~1K');

$size = DCBCommon::common_format_size(1048576);
ok($size =~ /1.*M/i, 'formats 1048576 bytes as ~1M');

$size = DCBCommon::common_format_size(1073741824);
ok($size =~ /1.*G/i, 'formats 1073741824 bytes as ~1G');

# Test common_escape_string
my $escaped = DCBCommon::common_escape_string('!test.+');
like($escaped, qr/\\!/, 'special chars are escaped');

done_testing();
