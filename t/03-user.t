#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

use DCBSettings;
$DCBSettings::config = {
    username_max_length => 30,
    botname             => 'TestBot',
    username_anonymous  => 'Anonymous',
    allow_anon          => 1,
    allow_external      => 1,
    allow_passive       => 1,
    minshare            => 0,
    db => {
        driver   => 'SQLite',
        database => ':memory:',
        path     => '',
        username => '',
        password => '',
    },
    botemail    => 'test@test.com',
    commandPath => 'commands',
};
$DCBSettings::cwd = '';

# Load DCBUser (and its dependency DCBDatabase) with constants exported
use DCBUser;

ok(1, 'DCBUser loaded successfully');

# Test PERMISSIONS constant
is(PERMISSIONS->{OFFLINE}, 0, 'OFFLINE permission is 0');
is(PERMISSIONS->{ANONYMOUS}, 4, 'ANONYMOUS permission is 4');
is(PERMISSIONS->{AUTHENTICATED}, 8, 'AUTHENTICATED permission is 8');
is(PERMISSIONS->{OPERATOR}, 16, 'OPERATOR permission is 16');
is(PERMISSIONS->{ADMINISTRATOR}, 32, 'ADMINISTRATOR permission is 32');

# Test user_permissions - single permission
is(DCBUser::user_permissions('ANONYMOUS'), 4, 'single permission resolves correctly');

# Test user_permissions - combined permissions (bitwise OR)
my $combined = DCBUser::user_permissions('ANONYMOUS', 'AUTHENTICATED');
is($combined, 12, 'combined permissions use bitwise OR');

# Test user_access
my $admin = { permission => 32 };
my $anon = { permission => 4 };
ok(DCBUser::user_access($admin, 32), 'admin has admin access');
ok(!DCBUser::user_access($anon, 32), 'anon does not have admin access');
ok(DCBUser::user_access($anon, 4), 'anon has anon access');

# Test user_is_admin
ok(DCBUser::user_is_admin({ permission => 32 }), 'administrator is admin');
ok(DCBUser::user_is_admin({ permission => 16 }), 'operator is admin');
ok(!DCBUser::user_is_admin({ permission => 8 }), 'authenticated is not admin');
ok(!DCBUser::user_is_admin({ permission => 4 }), 'anonymous is not admin');

# Test user_invalid_name
my @errors = DCBUser::user_invalid_name('validname');
is(scalar @errors, 0, 'valid name has no errors');

@errors = DCBUser::user_invalid_name('a' x 31);
ok(scalar @errors > 0, 'name over max length returns errors');

@errors = DCBUser::user_invalid_name('bad name!');
ok(scalar @errors > 0, 'name with special chars returns errors');

@errors = DCBUser::user_invalid_name('TestBot');
ok(scalar @errors > 0, 'bot name is rejected');

@errors = DCBUser::user_invalid_name('Anonymous');
ok(scalar @errors > 0, 'anonymous name is rejected');

# Test valid name patterns
@errors = DCBUser::user_invalid_name('user-name_123');
is(scalar @errors, 0, 'hyphens and underscores allowed');

done_testing();
