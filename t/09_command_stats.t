use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../commands";
use lib "$FindBin::Bin/lib";
use MockODCH;
use File::Temp qw(tempdir);

use DCBSettings;
use TestHelper;
my ($tmpdir, $config) = TestHelper::setup();

# Fix db path for SQLite connection
$DCBSettings::config->{db}->{path} = '.';
$DCBSettings::cwd = "$tmpdir/";

use DCBDatabase;
use DCBCommon;

# Connect and install base tables
DCBDatabase::db_connect();
DCBDatabase::db_install();

# Load stats command and install its schema
use stats;
my $schema = stats::schema();
DCBDatabase::db_create_table($schema);

my $test_user = { uid => 1, name => 'TestUser', permission => 4 };

# ---- Test init with empty table ----
stats::init();
ok( defined $DCBCommon::COMMON->{stats}->{hubstats}, 'init creates hubstats' );
is( $DCBCommon::COMMON->{stats}->{hubstats}->{connections}, 0, 'Initial connections is 0' );
is( $DCBCommon::COMMON->{stats}->{hubstats}->{disconnections}, 0, 'Initial disconnections is 0' );
is( $DCBCommon::COMMON->{stats}->{hubstats}->{number_users}, 0, 'Initial users is 0' );
is( $DCBCommon::COMMON->{stats}->{max_users}, 0, 'Initial max_users is 0' );
is( $DCBCommon::COMMON->{stats}->{max_share}, 0, 'Initial max_share is 0' );

# ---- Test main returns formatted stats ----
my @result = stats::main(undef, $test_user, '');
is( scalar @result, 1, 'main returns one message' );
is( $result[0]->{param}, 'message', 'Action is message' );
is( $result[0]->{type}, MESSAGE->{'PUBLIC_SINGLE'}, 'Message type is PUBLIC_SINGLE' );
like( $result[0]->{message}, qr/Hub Stats at/, 'Contains hub stats header' );
like( $result[0]->{message}, qr/Connections =>/, 'Contains connections' );
like( $result[0]->{message}, qr/Disconnections =>/, 'Contains disconnections' );
like( $result[0]->{message}, qr/Total Share =>/, 'Contains total share' );
like( $result[0]->{message}, qr/User Number =>/, 'Contains user number' );
like( $result[0]->{message}, qr/Searches =>/, 'Contains searches' );
like( $result[0]->{message}, qr/Historical High Users =>/, 'Contains historical high users' );
like( $result[0]->{message}, qr/Historical High Share =>/, 'Contains historical high share' );

# ---- Test timer inserts snapshot ----
# Simulate some hub activity
$DCBCommon::COMMON->{stats}->{hubstats}->{connections} = 10;
$DCBCommon::COMMON->{stats}->{hubstats}->{number_users} = 5;
$DCBCommon::COMMON->{stats}->{hubstats}->{total_share} = 1073741824;
$DCBCommon::COMMON->{stats}->{hubstats}->{disconnections} = 3;
$DCBCommon::COMMON->{stats}->{hubstats}->{searches} = 42;

stats::timer();

# Verify a new row was inserted
my $sth = DCBDatabase::db_select('stats', ['*'], {}, {-desc => 'sid'});
my $latest = $sth->fetchrow_hashref();
ok( defined $latest, 'timer inserted a stats snapshot' );
is( $latest->{connections}, 10, 'Snapshot connections matches' );
is( $latest->{number_users}, 5, 'Snapshot users matches' );

# ---- Test init loads historical max after timer runs ----
stats::init();
is( $DCBCommon::COMMON->{stats}->{max_users}, 5, 'max_users reflects highest value' );
ok( $DCBCommon::COMMON->{stats}->{max_share} >= 1073741824, 'max_share reflects highest value' );

# ---- Test multiple snapshots track max correctly ----
$DCBCommon::COMMON->{stats}->{hubstats}->{number_users} = 20;
$DCBCommon::COMMON->{stats}->{hubstats}->{total_share} = 5368709120;
stats::timer();

stats::init();
is( $DCBCommon::COMMON->{stats}->{max_users}, 20, 'max_users updated to higher value' );

done_testing;
