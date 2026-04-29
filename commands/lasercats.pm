package commands::lasercats;
use strict; use warnings;

sub name { 'lasercats' }
sub aliases { () }
sub help { '!lasercats — PEW PEW PEW (also kicks you)' }

sub run {
    my ($from_nick, $args, $gateway) = @_;
    eval { $gateway->kick_user($from_nick, 'LASERCATS PEW PEW PEW') };
    return "/\\_/\\  PEW PEW PEW\n ( o.o ) ----=======\n  > ^ <";
}

1;
