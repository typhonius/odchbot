package commands_v4::lasercats;
use strict; use warnings;

sub name { 'lasercats' }
sub aliases { () }
sub help { '!lasercats — PEW PEW PEW (also kicks you)' }

sub run {
    my ($from_nick, $args, $client, $gateway) = @_;
    $client->send_chat('  /\_/\  PEW PEW PEW');
    $client->send_chat(' ( o.o ) ----=======');
    $client->send_chat('  > ^ <');
    # Kick the invoker (tradition!)
    eval {
        my $ua = $gateway->{ua};
        my $url = "$gateway->{base_url}/api/v1/users/$from_nick/kick";
        my $req = HTTP::Request->new(POST => $url);
        $req->header('Content-Type' => 'application/json');
        $req->header('X-API-Key' => $gateway->{api_key});
        $req->content('{"reason":"LASERCATS PEW PEW PEW"}');
        $ua->request($req);
    };
    return undef; # already sent
}

1;
