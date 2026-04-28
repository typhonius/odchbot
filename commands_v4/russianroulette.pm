package commands_v4::russianroulette;
use strict; use warnings;

sub name { 'russianroulette' }
sub aliases { ('rr') }
sub help { '!rr — Play Russian roulette (1/6 chance of kick)' }

sub run {
    my ($from_nick, $args, $client, $gateway) = @_;
    if (int(rand(6)) == 0) {
        $client->send_chat("*BANG* $from_nick is dead!");
        # Kick via gateway API
        eval {
            my $ua = $gateway->{ua};
            my $url = "$gateway->{base_url}/api/v1/users/$from_nick/kick";
            my $req = HTTP::Request->new(POST => $url);
            $req->header('Content-Type' => 'application/json');
            $req->header('X-API-Key' => $gateway->{api_key});
            $req->content('{"reason":"Russian roulette"}');
            $ua->request($req);
        };
        return undef; # already sent
    }
    return "*click* $from_nick survives!";
}

1;
