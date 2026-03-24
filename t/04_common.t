use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/lib";
use MockODCH;

use DCBSettings;
$DCBSettings::config = {
    timezone => 'UTC',
};

use DCBCommon;

# ---- Test MESSAGE constant ----
is( MESSAGE->{HUB_PUBLIC},      1,  'HUB_PUBLIC is 1' );
is( MESSAGE->{PUBLIC_SINGLE},   2,  'PUBLIC_SINGLE is 2' );
is( MESSAGE->{BOT_PM},          3,  'BOT_PM is 3' );
is( MESSAGE->{PUBLIC_ALL},      4,  'PUBLIC_ALL is 4' );
is( MESSAGE->{MASS_MESSAGE},    5,  'MASS_MESSAGE is 5' );
is( MESSAGE->{SPOOF_PM_BOTH},   6,  'SPOOF_PM_BOTH is 6' );
is( MESSAGE->{SEND_TO_OPS},     7,  'SEND_TO_OPS is 7' );
is( MESSAGE->{HUB_PM},          8,  'HUB_PM is 8' );
is( MESSAGE->{SPOOF_PM_SINGLE}, 9,  'SPOOF_PM_SINGLE is 9' );
is( MESSAGE->{SPOOF_PUBLIC},    10, 'SPOOF_PUBLIC is 10' );
is( MESSAGE->{RAW},             11, 'RAW is 11' );
is( MESSAGE->{SEND_TO_ADMINS},  12, 'SEND_TO_ADMINS is 12' );

# ---- Test common_escape_string ----
# The function escapes regex metacharacters by prepending backslash

my $escaped = DCBCommon::common_escape_string('hello.world');
is( $escaped, 'hello\.world', 'Dot is escaped to backslash-dot' );

$escaped = DCBCommon::common_escape_string('test+value');
is( $escaped, 'test\+value', 'Plus is escaped' );

$escaped = DCBCommon::common_escape_string('a*b?c');
is( $escaped, 'a\*b\?c', 'Wildcards * and ? are escaped' );

$escaped = DCBCommon::common_escape_string('(group)');
is( $escaped, '\(group\)', 'Parentheses are escaped' );

$escaped = DCBCommon::common_escape_string('[bracket]');
is( $escaped, '\[bracket]', 'Open bracket is escaped' );

$escaped = DCBCommon::common_escape_string('{brace}');
is( $escaped, '\{brace}', 'Open brace is escaped' );

$escaped = DCBCommon::common_escape_string('$dollar');
is( $escaped, '\$dollar', 'Dollar sign is escaped' );

$escaped = DCBCommon::common_escape_string('a/b');
is( $escaped, 'a\/b', 'Forward slash is escaped' );

$escaped = DCBCommon::common_escape_string('a^b');
is( $escaped, 'a\^b', 'Caret is escaped' );

$escaped = DCBCommon::common_escape_string('a|b');
is( $escaped, 'a\|b', 'Pipe is escaped' );

# String with no special characters
$escaped = DCBCommon::common_escape_string('normalstring');
is( $escaped, 'normalstring', 'Normal string is unchanged' );

# Empty string
$escaped = DCBCommon::common_escape_string('');
is( $escaped, '', 'Empty string returns empty' );

# String with multiple special chars
$escaped = DCBCommon::common_escape_string('a.b+c*d');
is( $escaped, 'a\.b\+c\*d', 'Multiple special chars all escaped' );

# ---- Test common_timestamp_time ----
my $timestamp = DCBCommon::common_timestamp_time(0);
is( $timestamp, '1970-01-01 00:00:00', 'Epoch 0 formats correctly in UTC' );

$timestamp = DCBCommon::common_timestamp_time(1000000000);
is( $timestamp, '2001-09-09 01:46:40', 'Known epoch 1000000000 formats correctly' );

$timestamp = DCBCommon::common_timestamp_time(86400);
is( $timestamp, '1970-01-02 00:00:00', 'Epoch 86400 (one day) formats correctly' );

$timestamp = DCBCommon::common_timestamp_time(1609459200);
is( $timestamp, '2021-01-01 00:00:00', 'New Year 2021 formats correctly' );

# ---- Test common_format_size ----
my $size = DCBCommon::common_format_size(1024);
is( $size, '1.0KiB', 'Format 1024 bytes = 1.0KiB' );

$size = DCBCommon::common_format_size(1073741824);
is( $size, '1.0GiB', 'Format 1073741824 bytes = 1.0GiB' );

$size = DCBCommon::common_format_size(1048576);
is( $size, '1.0MiB', 'Format 1048576 bytes = 1.0MiB' );

$size = DCBCommon::common_format_size(0);
is( $size, '0', 'Format 0 bytes = 0' );

$size = DCBCommon::common_format_size(500);
ok( defined $size, 'Format 500 bytes returns a defined value' );

# ---- Test common_timestamp_duration ----
# This tests relative duration from a past epoch to now.
# We can only verify it returns a non-empty string.
my $duration = DCBCommon::common_timestamp_duration(0);
ok( defined $duration && length($duration) > 0, 'Duration from epoch 0 returns non-empty string' );
like( $duration, qr/years/, 'Duration from epoch 0 contains "years"' );

done_testing;
