#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use File::Temp qw(tempdir);
use File::Spec;

use ODCHBot::Database;

my $tmpdir = tempdir(CLEANUP => 1);
my $db_file = File::Spec->catfile($tmpdir, 'test.db');

my $db = ODCHBot::Database->new(dsn => "dbi:SQLite:$db_file");

# Table creation
{
    $db->create_table('test_table', {
        id   => { type => 'INTEGER', primary => 1, autoincrement => 1 },
        name => { type => 'TEXT', not_null => 1 },
        val  => { type => 'INTEGER', default => 0 },
    });
    ok($db->table_exists('test_table'), 'table created');
}

# ensure_table (idempotent)
{
    lives_ok {
        $db->ensure_table('test_table', {
            id   => { type => 'INTEGER', primary => 1, autoincrement => 1 },
            name => { type => 'TEXT', not_null => 1 },
        })
    } 'ensure_table does not fail on existing table';
}

# Insert + select
{
    my $id = $db->insert('test_table', { name => 'foo', val => 10 });
    ok($id, 'insert returns an id');

    my $row = $db->select_one('test_table', '*', { name => 'foo' });
    is($row->{name}, 'foo', 'select finds inserted row');
    is($row->{val}, 10, 'value matches');
}

# Update
{
    $db->update('test_table', { val => 20 }, { name => 'foo' });
    my $row = $db->select_one('test_table', '*', { name => 'foo' });
    is($row->{val}, 20, 'update changes value');
}

# Count
{
    $db->insert('test_table', { name => 'bar', val => 30 });
    is($db->count('test_table'), 2, 'count returns correct number');
    is($db->count('test_table', { name => 'foo' }), 1, 'count with where clause');
}

# Select multiple
{
    my $rows = $db->select('test_table', '*', undef, 'name');
    is(scalar @$rows, 2, 'select returns all rows');
    is($rows->[0]{name}, 'bar', 'ordered by name');
}

# Delete
{
    $db->delete_rows('test_table', { name => 'bar' });
    is($db->count('test_table'), 1, 'delete removes row');
}

# Drop table
{
    $db->drop_table('test_table');
    ok(!$db->table_exists('test_table'), 'table dropped');
}

# do_sql
{
    $db->do_sql("CREATE TABLE raw_test (x INTEGER)");
    $db->do_sql("INSERT INTO raw_test VALUES (?)", 42);
    my $row = $db->select_one('raw_test', '*');
    is($row->{x}, 42, 'do_sql works for raw queries');
}

$db->disconnect;
done_testing();
