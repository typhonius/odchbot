package commands_v4::roll;
use strict; use warnings;

sub name { 'roll' }
sub aliases { () }
sub help { '!roll [NdS] — Roll dice (e.g. !roll 2d6)' }

sub run {
    my ($from_nick, $args, $client, $gateway) = @_;
    my ($count, $sides) = ($args =~ /^(\d+)?d(\d+)$/i);
    $count ||= 1; $sides ||= 6;
    $count = 10 if $count > 10;
    $sides = 1000 if $sides > 1000;
    my @rolls = map { int(rand($sides)) + 1 } 1..$count;
    my $total = 0; $total += $_ for @rolls;
    return sprintf("%s rolled %dd%d: %s (total: %d)",
        $from_nick, $count, $sides, join(', ', @rolls), $total);
}

1;
