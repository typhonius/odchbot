package commands::lasercats;
use strict; use warnings;

sub name { 'lasercats' }
sub aliases { () }
sub help { '!lasercats — PEW PEW PEW (also kicks you)' }

sub run {
    my ($from_nick, $args, $gateway) = @_;
    # Send chat first so the user sees it before getting kicked
    eval { $gateway->chat("/\\_/\\  PEW PEW PEW\n ( o.o ) ----=======\n  > ^ <") };
    # Delay so the chat message reaches the client before the kick
    # closes their TCP connection
    select(undef, undef, undef, 0.5);
    eval { $gateway->kick_user($from_nick, 'LASERCATS PEW PEW PEW') };
    return undef;  # already sent chat directly
}

1;
