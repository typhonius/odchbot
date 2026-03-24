use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/lib";
use MockODCH;
use File::Temp qw(tempdir);

# Set up config for database before loading modules
use DCBSettings;
my $tmpdir = tempdir( CLEANUP => 1 );

$DCBSettings::config = {
    db => {
        driver   => 'SQLite',
        database => 'test.db',
        path     => '.',
        host     => '',
        port     => '',
        username => '',
        password => '',
    },
    botname            => 'TestBot',
    botemail           => 'test@test.com',
    username_anonymous => 'Anonymous',
};
# db_connect builds: $DCBSettings::cwd . $db->{path} . '/' . $db->{database}
$DCBSettings::cwd = "$tmpdir/";

use DCBDatabase;

# ---- Test db_connect ----
eval { DCBDatabase::db_connect(); };
ok( !$@, 'Database connection succeeds' ) or diag $@;
ok( defined $DCBDatabase::dbh, 'Database handle is defined' );

# ---- Test db_install (creates tables) ----
eval { DCBDatabase::db_install(); };
ok( !$@, 'Database installation succeeds' ) or diag $@;

# ---- Test db_table_exists ----
ok( DCBDatabase::db_table_exists('users'),    'users table exists after install' );
ok( DCBDatabase::db_table_exists('registry'), 'registry table exists after install' );
ok( DCBDatabase::db_table_exists('watchdog'), 'watchdog table exists after install' );
ok( !DCBDatabase::db_table_exists('nonexistent'), 'nonexistent table does not exist' );

# ---- Test that install created default records ----
my @fields = ('*');
my %where_anon = ( name => 'Anonymous' );
my $sth = DCBDatabase::db_select( 'users', \@fields, \%where_anon );
my $anon = $sth->fetchrow_hashref();
ok( defined $anon, 'Anonymous user created during install' );
is( $anon->{name}, 'Anonymous', 'Anonymous user name is correct' );

my %where_bot = ( name => 'TestBot' );
$sth = DCBDatabase::db_select( 'users', \@fields, \%where_bot );
my $bot = $sth->fetchrow_hashref();
ok( defined $bot, 'Bot user created during install' );
is( $bot->{name}, 'TestBot', 'Bot user name is correct' );
is( $bot->{mail}, 'test@test.com', 'Bot user email is correct' );
is( $bot->{permission}, 64, 'Bot user has TELNET (64) permission' );

# ---- Test db_insert and db_select ----
my %test_user = (
    name            => 'TestUser',
    mail            => 'test@example.com',
    permission      => 8,
    join_time       => 1000000,
    connect_time    => 1000000,
    disconnect_time => 0,
);
eval { DCBDatabase::db_insert( 'users', \%test_user ); };
ok( !$@, 'Insert user succeeds' ) or diag $@;

# Select with where clause
my %where_test = ( name => 'TestUser' );
$sth = DCBDatabase::db_select( 'users', \@fields, \%where_test );
my $user = $sth->fetchrow_hashref();
ok( defined $user, 'User retrieved from database' );
is( $user->{name},       'TestUser',         'User name matches' );
is( $user->{mail},       'test@example.com', 'User email matches' );
is( $user->{permission}, 8,                  'User permission matches' );

# Select specific fields
my @name_only = ('name');
$sth = DCBDatabase::db_select( 'users', \@name_only, \%where_test );
$user = $sth->fetchrow_hashref();
ok( defined $user,          'Select specific field works' );
is( $user->{name}, 'TestUser', 'Name field returned' );

# Select with no where (all rows)
$sth = DCBDatabase::db_select('users');
my $count = 0;
while ( $sth->fetchrow_hashref() ) { $count++; }
ok( $count >= 3, "Select all returns at least 3 users (got $count)" );

# ---- Test db_update ----
my %update_fields = ( permission => 16 );
my %update_where  = ( name       => 'TestUser' );
eval { DCBDatabase::db_update( 'users', \%update_fields, \%update_where ); };
ok( !$@, 'Update user succeeds' ) or diag $@;

$sth = DCBDatabase::db_select( 'users', \@fields, \%where_test );
$user = $sth->fetchrow_hashref();
is( $user->{permission}, 16, 'User permission updated to 16' );

# Update multiple fields
my %multi_update = ( permission => 32, mail => 'updated@example.com' );
eval { DCBDatabase::db_update( 'users', \%multi_update, \%update_where ); };
ok( !$@, 'Multi-field update succeeds' ) or diag $@;

$sth = DCBDatabase::db_select( 'users', \@fields, \%where_test );
$user = $sth->fetchrow_hashref();
is( $user->{permission}, 32,                    'Permission updated in multi-field update' );
is( $user->{mail},       'updated@example.com', 'Email updated in multi-field update' );

# ---- Test db_delete ----
my %del_where = ( name => 'TestUser' );
eval { DCBDatabase::db_delete( 'users', \%del_where ); };
ok( !$@, 'Delete user succeeds' ) or diag $@;

$sth = DCBDatabase::db_select( 'users', \@fields, \%where_test );
$user = $sth->fetchrow_hashref();
ok( !defined $user, 'User deleted from database' );

# ---- Test db_create_table with custom schema ----
my %schema = (
    schema => {
        test_table => {
            id => {
                type          => 'INTEGER',
                not_null      => 1,
                primary_key   => 1,
                autoincrement => 1,
            },
            data => { type => 'VARCHAR(255)' },
        },
    },
);
eval { DCBDatabase::db_create_table( \%schema ); };
ok( !$@, 'Create custom table succeeds' ) or diag $@;
ok( DCBDatabase::db_table_exists('test_table'), 'Custom table exists' );

# Insert into custom table
my %custom_row = ( data => 'hello world' );
eval { DCBDatabase::db_insert( 'test_table', \%custom_row ); };
ok( !$@, 'Insert into custom table succeeds' ) or diag $@;

my %custom_where = ( data => 'hello world' );
$sth = DCBDatabase::db_select( 'test_table', ['*'], \%custom_where );
my $row = $sth->fetchrow_hashref();
ok( defined $row, 'Row retrieved from custom table' );
is( $row->{data}, 'hello world', 'Custom table data matches' );

# Verify autoincrement worked
ok( defined $row->{id} && $row->{id} > 0, 'Autoincrement ID assigned' );

# ---- Test db_drop_table ----
eval { DCBDatabase::db_drop_table( \%schema ); };
ok( !$@, 'Drop table succeeds' ) or diag $@;
ok( !DCBDatabase::db_table_exists('test_table'), 'Custom table dropped' );

# ---- Test db_create_table is idempotent (doesn't error on existing table) ----
my %schema2 = (
    schema => {
        idempotent_test => {
            id   => { type => 'INTEGER', not_null => 1, primary_key => 1 },
            name => { type => 'VARCHAR(50)' },
        },
    },
);
eval { DCBDatabase::db_create_table( \%schema2 ); };
ok( !$@, 'First create succeeds' ) or diag $@;
eval { DCBDatabase::db_create_table( \%schema2 ); };
ok( !$@, 'Second create (idempotent) succeeds without error' ) or diag $@;
ok( DCBDatabase::db_table_exists('idempotent_test'), 'Table still exists after double create' );

# Clean up
eval { DCBDatabase::db_drop_table( \%schema2 ); };

# ---- Test db_do with raw SQL ----
eval { DCBDatabase::db_do("CREATE TABLE raw_test (id INTEGER, val TEXT)"); };
ok( !$@, 'db_do with raw SQL succeeds' ) or diag $@;
ok( DCBDatabase::db_table_exists('raw_test'), 'Raw SQL table created' );
eval { DCBDatabase::db_do("DROP TABLE raw_test"); };
ok( !$@, 'db_do DROP with raw SQL succeeds' ) or diag $@;

done_testing;
