# ODCHBot

Gateway-only bots for [OpenDCHub](https://github.com/typhonius/opendchub). No NMDC connection — bots register with the [gateway](https://github.com/typhonius/odch-gateway) API which creates virtual users on the hub. Commands arrive via SSE, responses go via HTTP.

## Bots

- **odchbot.pl** (Dragon) — Hub mascot. Fun commands: `!coin`, `!roll`, `!8ball`, `!lasercats`, `!rr`, `!time`
- **opchat.pl** (OPChat) — OP group chat relay. PMs to OPChat are forwarded to all online operators.

## Setup

```bash
cp odchbot.yml.example odchbot.yml   # edit gateway URL + API key
cp opchat.yml.example opchat.yml     # edit gateway URL + API key
mkdir -p logs
perl odchbot.pl                       # Dragon appears in hub user list
perl opchat.pl                        # OPChat appears in hub user list
```

## Requirements

- Perl 5.20+
- LWP::UserAgent, HTTP::Tiny, JSON, YAML::AppConfig, Log::Log4perl

## Architecture

```
odchbot.pl ──→ odch-gateway ──→ opendchub ←→ DC Clients
  (HTTP)        (virtual user)    (NMDC)
```

Bots only talk HTTP. The gateway creates virtual users on the hub so bots appear in the user list. Commands are delivered via Server-Sent Events (SSE), responses sent via the chat/PM API.

## Writing a New Command

Drop a `.pm` file in `commands/`:

```perl
package commands::hello;
use strict; use warnings;

sub name { 'hello' }
sub aliases { ('hi', 'hey') }
sub help { '!hello — Say hello' }

sub run {
    my ($from_nick, $args, $gateway) = @_;
    return "Hello $from_nick!";
}

1;
```

Restart the bot. The new command is auto-discovered and registered with the gateway.

## Config

```yaml
bot:
  nick: Dragon
  description: "I am Dragon, hear me RAWR"
  email: "dragon@dc.glo5.com"
  tag: "<odchbot V:4.0.0>"

gateway:
  url: "http://127.0.0.1:3000"
  api_key: "YOUR_API_KEY"
```

## Files

| File | Purpose |
|------|---------|
| odchbot.pl | Dragon bot — fun commands |
| opchat.pl | OPChat — OP PM relay |
| GatewayClient.pm | HTTP client for gateway bot platform API |
| NMDCClient.pm | Legacy NMDC client (unused in v4, kept for reference) |
| commands/*.pm | Command plugins (auto-discovered) |

## Related

- [odch-gateway](https://github.com/typhonius/odch-gateway) — Gateway + bot platform
- [opendchub](https://github.com/typhonius/opendchub) — NMDC hub server
