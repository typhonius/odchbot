use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/lib";
use MockODCH;
use File::Temp qw(tempfile);

use DCBSettings;

# ---- Test config_load with a YAML file in the project root ----
# config_load prepends the directory of DCBSettings.pm to the filename,
# so we write the test config there.
my $project_root = "$FindBin::Bin/../";

# Create a temp config file in the project root directory
my $test_config_name = '_test_config_' . $$ . '.yml';
my $test_config_path = $project_root . $test_config_name;

# Write test config
open my $fh, '>', $test_config_path or die "Cannot write config: $!";
print $fh <<'YAML';
---
config:
  botname: TestBot
  debug: 0
  timezone: UTC
  cp: "-"
  db:
    driver: SQLite
    database: test.db
YAML
close $fh;

eval {
    my $yaml = DCBSettings::config_load($test_config_name);
    ok( defined $yaml, 'Config file loads successfully' );

    my $conf = $yaml->get('config');
    is( $conf->{botname},  'TestBot', 'Bot name loaded from config' );
    is( $conf->{debug},    0,         'Debug setting loaded from config' );
    is( $conf->{timezone}, 'UTC',     'Timezone loaded from config' );
    is( $conf->{cp},       '-',       'CP setting loaded from config' );

    # Nested config
    is( $conf->{db}{driver},   'SQLite',  'Nested db driver loaded' );
    is( $conf->{db}{database}, 'test.db', 'Nested db name loaded' );
};
if ($@) {
    fail("Config loading failed: $@");
}

# Clean up temp config file
unlink $test_config_path;

# ---- Test config_get ----
$DCBSettings::config = {
    botname   => 'TestBot',
    debug     => 0,
    test_key  => 'test_value',
    empty_str => '',
};

is( DCBSettings::config_get('botname'),  'TestBot',    'config_get returns correct string value' );
is( DCBSettings::config_get('test_key'), 'test_value', 'config_get returns test_key value' );

# config_get returns 0 for missing keys
is( DCBSettings::config_get('nonexistent'), 0, 'config_get returns 0 for missing key' );

# config_get returns 0 for debug=0 (falsy value treated as 0 by Perl truthiness)
is( DCBSettings::config_get('debug'), 0, 'config_get returns 0 for falsy value' );

# config_get returns 0 for empty string (falsy in Perl)
is( DCBSettings::config_get('empty_str'), 0, 'config_get returns 0 for empty string (falsy)' );

# ---- Test config_init via class method ----
# config_init calls config_load internally, so test it with our temp file
my $test_config_name2 = '_test_config2_' . $$ . '.yml';
my $test_config_path2 = $project_root . $test_config_name2;
open $fh, '>', $test_config_path2 or die "Cannot write config: $!";
print $fh <<'YAML';
---
config:
  botname: InitBot
  hubname: InitHub
  timezone: UTC
YAML
close $fh;

eval {
    DCBSettings->config_init($test_config_name2);
    is( $DCBSettings::config->{botname}, 'InitBot',  'config_init sets botname' );
    is( $DCBSettings::config->{hubname}, 'InitHub',  'config_init sets hubname' );
    is( $DCBSettings::config->{timezone}, 'UTC',     'config_init sets timezone' );
};
if ($@) {
    fail("config_init failed: $@");
}

# Clean up
unlink $test_config_path2;

done_testing;
