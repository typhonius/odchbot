#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";
use File::Temp qw(tempfile);
use File::Basename;
use Cwd 'abs_path';

# config_load constructs the path relative to DCBSettings.pm's directory,
# so we create our temp config file in that same directory.
my $base = "$FindBin::Bin/..";
my ($fh, $tmpfile) = tempfile(
    'test_config_XXXX',
    SUFFIX => '.yml',
    DIR    => $base,
    UNLINK => 1,
);
print $fh <<'YAML';
config:
  db:
    driver: SQLite
    database: test_odchbot.db
    path: /tmp
  botname: TestBot
  botdescription: Test bot
  version: v3-test
  timezone: UTC
  cp: "!"
  bottag: ODCHBot
  botemail: test@test.com
  botshare: 0
  botspeed: "1"
  username_anonymous: Anonymous
  username_max_length: 30
  allow_anon: 1
  allow_external: 1
  allow_passive: 1
  minshare: 0
  commandPath: commands
  topic: Test Hub
  debug: 0
YAML
close $fh;

# Extract just the filename since config_load prepends $cwd
my $config_name = basename($tmpfile);

use_ok('DCBSettings');

my $settings = DCBSettings->new();
isa_ok($settings, 'DCBSettings');

# Test config_load with our temp file
my $yaml = DCBSettings::config_load($config_name);
ok(defined $yaml, 'config_load returns a value');

# Initialize config from temp file
$settings->config_init($config_name);
is($DCBSettings::config->{botname}, 'TestBot', 'botname loaded correctly');
is($DCBSettings::config->{version}, 'v3-test', 'version loaded correctly');
is($DCBSettings::config->{timezone}, 'UTC', 'timezone loaded correctly');
is($DCBSettings::config->{db}->{driver}, 'SQLite', 'db driver loaded correctly');

# Test config_get
is(DCBSettings::config_get('botname'), 'TestBot', 'config_get works');
is(DCBSettings::config_get('nonexistent'), 0, 'config_get returns 0 for missing key');

done_testing();
