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

# Fix db path for SQLite connection (cwd + path + / + database)
$DCBSettings::config->{db}->{path} = '.';
$DCBSettings::cwd = "$tmpdir/";

use DCBDatabase;
use DCBCommon;
use DCBUser;

# Connect and install base tables
DCBDatabase::db_connect();
DCBDatabase::db_install();

# Load ban command and install its schema
use ban;
my $schema = ban::schema();
DCBDatabase::db_create_table($schema);

# Set ban config values
$DCBSettings::config->{ban_default_ban_time} = 300;
$DCBSettings::config->{ban_default_ban_message} = 'You are banned';
$DCBSettings::config->{ban_handler} = 'bot';
$DCBSettings::config->{no_perms} = 'You do not have adequate permissions!';

# Create test users in database
my %op_user_db = (
    name            => 'OpUser',
    mail            => 'op@test.com',
    permission      => 16,
    join_time       => 1000000,
    connect_time    => time(),
    disconnect_time => 0,
);
DCBDatabase::db_insert('users', \%op_user_db);
my $op_sth = DCBDatabase::db_select('users', ['uid'], {name => 'OpUser'});
my $op_uid = ($op_sth->fetchrow_array())[0];

my %victim_db = (
    name            => 'Victim',
    mail            => 'victim@test.com',
    permission      => 4,
    join_time       => 1000000,
    connect_time    => time(),
    disconnect_time => 0,
);
DCBDatabase::db_insert('users', \%victim_db);
my $victim_sth = DCBDatabase::db_select('users', ['uid'], {name => 'Victim'});
my $victim_uid = ($victim_sth->fetchrow_array())[0];

# Set up in-memory userlist for command lookups
$DCBUser::userlist = {
    'victim' => {
        uid        => $victim_uid,
        name       => 'Victim',
        permission => 4,
    },
    'opuser' => {
        uid        => $op_uid,
        name       => 'OpUser',
        permission => 16,
    },
};

my $op_user = { uid => $op_uid, name => 'OpUser', permission => 16 };
my $victim  = { uid => $victim_uid, name => 'Victim', permission => 4 };

# ---- Test ban_calculate_ban_time ----
is( ban::ban_calculate_ban_time('60'),  60,          'Plain seconds' );
is( ban::ban_calculate_ban_time('5m'),  300,         '5 minutes' );
is( ban::ban_calculate_ban_time('2h'),  7200,        '2 hours' );
is( ban::ban_calculate_ban_time('1d'),  86400,       '1 day' );
is( ban::ban_calculate_ban_time('1w'),  604800,      '1 week' );
is( ban::ban_calculate_ban_time('1y'),  31536000,    '1 year' );
is( ban::ban_calculate_ban_time('10s'), 10,          '10 seconds with s suffix' );

# ---- Test init ----
ban::init();
ok( defined $DCBCommon::COMMON->{ban}->{banned_uids}, 'init creates banned_uids hash' );
is( scalar keys %{$DCBCommon::COMMON->{ban}->{banned_uids}}, 0, 'banned_uids starts empty' );

# ---- Test main with no params ----
my @result = ban::main(undef, $op_user, '');
is( scalar @result, 1, 'No params returns one message' );
like( $result[0]->{message}, qr/must specify parameters/, 'Error message about missing params' );

# ---- Test main with non-existent user ----
@result = ban::main(undef, $op_user, 'NonExistent');
is( scalar @result, 1, 'Non-existent user returns one message' );
like( $result[0]->{message}, qr/does not exist/, 'Error about non-existent user' );

# ---- Test main with valid user ----
@result = ban::main(undef, $op_user, 'Victim 10m Test ban');
ok( scalar @result > 1, 'Valid ban returns multiple actions' );

# Check that we get ban message, kick action, and log
my @messages = grep { $_->{param} eq 'message' } @result;
my @actions  = grep { $_->{param} eq 'action' } @result;
my @logs     = grep { $_->{param} eq 'log' } @result;

ok( scalar @messages >= 1, 'Ban produces at least one message' );
ok( scalar @actions >= 1,  'Ban produces a kick action' );
ok( scalar @logs >= 1,     'Ban produces a log entry' );

# Check kick action
my ($kick) = grep { $_->{action} && $_->{action} eq 'kick' } @actions;
ok( defined $kick, 'Kick action present' );
is( $kick->{user}, 'Victim', 'Kick targets the victim' );

# Check that ban was cached
is( $DCBCommon::COMMON->{ban}->{banned_uids}->{$victim_uid}, 1, 'Ban cached in memory after main()' );

# ---- Test ban_check_fast ----
is( ban::ban_check_fast($victim), 1, 'ban_check_fast returns 1 for banned user' );
is( ban::ban_check_fast({uid => 99999}), 0, 'ban_check_fast returns 0 for non-banned user' );

# ---- Test prelogin for banned user ----
@result = ban::prelogin(undef, $victim);
ok( scalar @result > 0, 'prelogin returns actions for banned user' );
my @kicks = grep { $_->{param} eq 'action' && $_->{action} eq 'kick' } @result;
ok( scalar @kicks >= 1, 'prelogin kicks banned user' );
my @ban_msgs = grep { $_->{param} eq 'message' } @result;
ok( scalar @ban_msgs >= 1, 'prelogin shows ban info message' );
like( $ban_msgs[0]->{message}, qr/BANNED/, 'Ban message contains BANNED text' );

# ---- Test prelogin for non-banned user ----
my $clean_user = { uid => $op_uid, name => 'OpUser', permission => 16 };
@result = ban::prelogin(undef, $clean_user);
ok( !@result, 'prelogin returns nothing for non-banned user' );

# ---- Test permission check (victim can't ban op) ----
@result = ban::main(undef, $victim, 'OpUser 10m');
is( scalar @result, 1, 'Insufficient permissions returns one message' );
like( $result[0]->{message}, qr/permissions/, 'Permission denied message' );

# ---- Test timer removes expired bans ----
# Insert an expired ban directly
my %expired_ban = (
    op_uid  => $op_uid,
    uid     => 88888,
    time    => time() - 1000,
    expire  => time() - 1,
    message => 'Expired',
);
DCBDatabase::db_insert('ban', \%expired_ban);
$DCBCommon::COMMON->{ban}->{banned_uids}->{88888} = 1;

ban::timer();
is( $DCBCommon::COMMON->{ban}->{banned_uids}->{88888}, undef, 'timer removes expired ban from cache' );

# Verify expired ban deleted from DB
my $check_sth = DCBDatabase::db_select('ban', ['uid'], {uid => 88888});
ok( !$check_sth->fetchrow_array(), 'timer deletes expired ban from database' );

done_testing;
