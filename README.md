# ODCHBot v4

Standalone NMDC client bots for OpenDCHub. Connects to the hub as a regular DC user, appears in the user list, and calls the [odch-gateway](https://github.com/typhonius/odch-gateway) API for all data operations.

## Components

- **odchbot.pl** — Main bot (Dragon). Fun commands, external integrations, custom plugins.
- **opchat.pl** — OP group chat. PMs to this bot are relayed to all online operators.
- **NMDCClient.pm** — NMDC protocol client (Lock/Key, chat, PM, join/quit events).
- **GatewayClient.pm** — HTTP client for the gateway bot API.
- **commands_v4/** — Modular command plugins (coin, roll, 8ball, etc.)

## Setup

```bash
cp odchbot.yml.example odchbot.yml   # edit hub/gateway settings
cp opchat.yml.example opchat.yml     # edit hub/gateway settings
mkdir -p logs
perl odchbot.pl                       # start the bot
perl opchat.pl                        # start OP chat (optional)
```

## Requirements

- Perl 5.20+
- LWP::UserAgent, JSON, YAML::AppConfig, Log::Log4perl, IO::Select

## Architecture

ODCHBot v4 is a standalone process. It does NOT run inside the hub's embedded Perl (that was v3).

```
Hub (NMDC) ←──── odchbot.pl (NMDC client)
                      │
                      ▼
               odch-gateway (HTTP API for data)
                      │
                      ▼
                  PostgreSQL
```

The gateway handles core commands (ban, tell, history, stats). The bot handles fun/personality commands (coin, roll, 8ball, lasercats) and custom plugins.
