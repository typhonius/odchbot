package commands::russianroulette;
use strict; use warnings;

sub name { 'russianroulette' }
sub aliases { ('rr') }
sub help { '!rr — Play Russian roulette (1/6 chance of kick)' }

sub run {
    my ($from_nick, $args, $gateway) = @_;
    if (int(rand(6)) == 0) {
        # Send chat first so everyone sees it before the user is kicked
        eval { $gateway->chat("*BANG* $from_nick is dead!") };
        eval { $gateway->kick_user($from_nick, 'Russian roulette') };
        return undef;  # already sent chat directly
    }
    return "*click* $from_nick survives!";
}

1;
