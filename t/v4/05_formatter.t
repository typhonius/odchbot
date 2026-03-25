#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use ODCHBot::Formatter qw(format_timestamp format_duration format_duration_short format_size escape_string);

# format_timestamp
{
    my $ts = format_timestamp(0, 'UTC');
    like($ts, qr/1970-01-01 00:00:00/, 'epoch 0 formats correctly');
}

# format_duration
{
    is(format_duration(0), '0 seconds', 'zero seconds');
    my $dur = format_duration(90);
    like($dur, qr/1 minute/, '90 seconds includes minute');
}

# format_duration_short
{
    is(format_duration_short(0), '0s', 'zero');
    is(format_duration_short(61), '1m 1s', '61 seconds');
    is(format_duration_short(3661), '1h 1m 1s', 'hours, minutes, seconds');
    is(format_duration_short(86400), '1d', 'one day');
}

# format_size
{
    my $s = format_size(1073741824);
    like($s, qr/1.*G/i, '1 GB formats correctly');

    my $s2 = format_size(0);
    ok(defined $s2, 'handles zero bytes');
}

# escape_string
{
    is(escape_string('hello'), 'hello', 'plain string unchanged');
    like(escape_string('$pipe|test'), qr/&#36;.*&#124;/, 'escapes $ and |');
    is(escape_string(undef), '', 'undef returns empty string');
}

done_testing();
