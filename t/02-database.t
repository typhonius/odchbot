#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";
use File::Temp qw(tempdir);

# Set up a temporary config for database testing
my $tmpdir = tempdir(CLEANUP => 1);

use DCBSettings;
my $settings = DCBSettings->new();

# Manually set config for testing
$DCBSettings::config = {
    db => {
        driver   => 'SQLite',
        database => 'test.db',
        path     => "$tmpdir/",
        username => '',
        password => '',
    },
    botname            => 'TestBot',
    botemail           => 'test@test.com',
    username_anonymous => 'Anonymous',
    commandPath        => 'commands',
};
$DCBSettings::cwd = '';

use_ok('DCBDatabase');

my $db = DCBDatabase->new();
isa_ok($db, 'DCBDatabase');

# Test connection
DCBDatabase::db_connect();
ok(defined $DCBDatabase::dbh, 'database handle created');

# Test table creation
my %schema = (
    schema => {
        test_table => {
            id   => { type => 'INTEGER', not_null => 1, primary_key => 1, autoincrement => 1 },
            name => { type => 'VARCHAR(128)' },
            val  => { type => 'INT' },
        },
    },
);
DCBDatabase::db_create_table(\%schema);
ok(DCBDatabase::db_table_exists('test_table'), 'table created successfully');

# Test insert
my %row = (name => 'test_user', val => 42);
my $sth = DCBDatabase::db_insert('test_table', \%row);
ok(defined $sth, 'insert succeeded');

# Test select
my @fields = ('*');
my %where = (name => 'test_user');
$sth = DCBDatabase::db_select('test_table', \@fields, \%where);
ok(defined $sth, 'select succeeded');
my $row = $sth->fetchrow_hashref();
is($row->{name}, 'test_user', 'select returns correct name');
is($row->{val}, 42, 'select returns correct value');

# Test update
my %updates = (val => 99);
$sth = DCBDatabase::db_update('test_table', \%updates, \%where);
ok(defined $sth, 'update succeeded');
$sth = DCBDatabase::db_select('test_table', \@fields, \%where);
$row = $sth->fetchrow_hashref();
is($row->{val}, 99, 'update applied correctly');

# Test select with limit
my %row2 = (name => 'user2', val => 10);
my %row3 = (name => 'user3', val => 20);
DCBDatabase::db_insert('test_table', \%row2);
DCBDatabase::db_insert('test_table', \%row3);
$sth = DCBDatabase::db_select('test_table', \@fields, undef, undef, 2);
my @rows;
while (my $r = $sth->fetchrow_hashref()) { push @rows, $r; }
is(scalar @rows, 2, 'select with limit returns correct count');

# Test delete
$sth = DCBDatabase::db_delete('test_table', \%where);
ok(defined $sth, 'delete succeeded');
$sth = DCBDatabase::db_select('test_table', \@fields, {name => 'test_user'});
$row = $sth->fetchrow_hashref();
ok(!defined $row, 'row deleted successfully');

# Test db_table_exists for non-existent table
ok(!DCBDatabase::db_table_exists('nonexistent_table'), 'nonexistent table returns false');

# Test db_drop_table
DCBDatabase::db_drop_table(\%schema);
ok(!DCBDatabase::db_table_exists('test_table'), 'table dropped successfully');

done_testing();
