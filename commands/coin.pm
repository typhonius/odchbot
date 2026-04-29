package commands::coin;
use strict; use warnings;

sub name { 'coin' }
sub aliases { () }
sub help { '!coin — Flip a coin' }

sub run {
    my ($from_nick, $args, $gateway) = @_;
    my @options = ('Heads!', 'Tails!');
    return $options[int(rand(2))];
}

1;
