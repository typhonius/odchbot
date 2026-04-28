package commands_v4::time;
use strict; use warnings;
use POSIX qw(strftime);

sub name { 'time' }
sub aliases { () }
sub help { '!time — Show current UTC time' }

sub run {
    my ($from_nick, $args, $client, $gateway) = @_;
    return strftime("Current time: %Y-%m-%d %H:%M:%S UTC", gmtime);
}

1;
