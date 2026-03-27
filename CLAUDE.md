# ODCHBot

Perl bot for OpenDCHub (NMDC protocol Direct Connect hub).

## Repo

- **GitHub**: github.com/typhonius/odchbot
- **Main branch**: `v3` (default, PRs target this)
- **Remote**: HTTPS (no SSH keys on dev machine)

## Architecture

- Entry points: `odchbot.pl` (main bot), `opchat.pl` (op chat)
- Core modules: `DCBSettings.pm`, `DCBDatabase.pm`, `DCBCommon.pm`, `DCBUser.pm`
- Commands: YAML config (`commands/*.yml`) + Perl module (`commands/*.pm`) per command
- Hooks: `init`, `line`, `postlogin`, `logout`, `timer`, `alter`, `prelogin`, `pm`, `search`
- Permissions bitmask: `OFFLINE(0)`, `ANONYMOUS(4)`, `AUTHENTICATED(8)`, `OPERATOR(16)`, `ADMINISTRATOR(32)`
- Config: `odchbot.yml` / `opchat.yml` (copied from `.example` files)
- Logging: Log4perl (`odchbot.log4perl.conf`, `opchat.log4perl.conf`)

## Database

Supports SQLite, MySQL, and PostgreSQL via DBI. Driver set in `odchbot.yml` under `db.driver`.
- `DCBDatabase::db_map_type()` handles Pg type mapping (SERIAL, SMALLINT, TEXT)
- Tables: `users`, `watchdog`, `registry`, plus command-specific tables (history, karma, etc.)

## Embedded Perl gotcha

OpenDCHub embeds libperl. The hub's CWD is its `WorkingDirectory` (e.g. `/opt/opendchub`), NOT the scripts directory. All file paths must use `$FindBin::Bin` for resolution. The Log4perl init reads the config file and rewrites relative `filename=` paths to absolute.

## Testing

```bash
# Install deps
cpanm --installdeps .

# Run tests
prove -r t/
```

CI runs on GitHub Actions (`.github/workflows/ci.yml`).

## Workflow

- Create feature/fix branches from `v3`
- PR to `v3`, CI must pass
- Don't push directly to `v3`

## Related repos

- **opendchub** (C hub): `/tmp/opendchub` locally, github.com/typhonius/opendchub
- **odch-gateway** (Rust API): `/tmp/odch-gateway` locally, github.com/typhonius/odch-gateway

## Server

- Host: `typhonius@seed` (cordyceps)
- Bot scripts: `/opt/opendchub/.opendchub/scripts/`
- Config: `/opt/opendchub/.opendchub/scripts/odchbot.yml`
- Service: `opendchub.service` (systemd, user `opendchub`)
- Database: PostgreSQL (`odchbot` database on localhost)
