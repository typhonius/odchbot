use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/lib";
use MockODCH;

# Need settings loaded before DCBUser
use DCBSettings;
$DCBSettings::config = {
    username_max_length  => 35,
    botname              => 'TestBot',
    username_anonymous   => 'Anonymous',
    allow_anon           => 1,
    allow_external       => 1,
    allow_passive        => 1,
    minshare             => 0,
};

use DCBUser;

my @errors;

# ---- Test user_invalid_name - valid names ----
# user_invalid_name is not exported, so call via package
@errors = DCBUser::user_invalid_name('ValidUser');
is( scalar @errors, 0, 'ValidUser is valid' );

@errors = DCBUser::user_invalid_name('user-name');
is( scalar @errors, 0, 'user-name with hyphen is valid' );

@errors = DCBUser::user_invalid_name('user_123');
is( scalar @errors, 0, 'user_123 with underscore and digits is valid' );

@errors = DCBUser::user_invalid_name('a');
is( scalar @errors, 0, 'Single character name is valid' );

@errors = DCBUser::user_invalid_name('ALLCAPS');
is( scalar @errors, 0, 'ALLCAPS name is valid' );

@errors = DCBUser::user_invalid_name('MiXeD-CaSe_123');
is( scalar @errors, 0, 'Mixed case with hyphens/underscores is valid' );

# Name at exactly max length
my $ok_name = 'a' x 35;
@errors = DCBUser::user_invalid_name($ok_name);
is( scalar @errors, 0, 'Name at max length (35) is valid' );

# ---- Test user_invalid_name - invalid names (length) ----
my $long_name = 'a' x 36;
@errors = DCBUser::user_invalid_name($long_name);
ok( scalar @errors > 0, 'Name exceeding max length (36) is invalid' );
like( $errors[0], qr/length/i, 'Error message mentions length' );

# ---- Test user_invalid_name - invalid names (characters) ----
# The regex ($name !~ /[\w-]+/) only fails for names with NO word chars at all
@errors = DCBUser::user_invalid_name('<<<>>>');
ok( scalar @errors > 0, 'Name with only special characters is invalid' );

@errors = DCBUser::user_invalid_name('user/path');
ok( scalar @errors > 0, 'Name with forward slash is invalid' );
like( $errors[0], qr/illegal/i, 'Error message mentions illegal characters' );

@errors = DCBUser::user_invalid_name('user\\path');
ok( scalar @errors > 0, 'Name with backslash is invalid' );

# Note: The current regex allows names like "user<script>" because
# the name contains word characters (\w matches 'user'), and the
# regex only checks if the name has NO word chars. This is a known
# limitation of the current validation logic.
@errors = DCBUser::user_invalid_name('user<script>');
is( scalar @errors, 0, 'Name with angle brackets but also word chars passes current regex' );

@errors = DCBUser::user_invalid_name('user name');
is( scalar @errors, 0, 'Name with space but also word chars passes current regex' );

# ---- Test user_invalid_name - reserved names ----
@errors = DCBUser::user_invalid_name('TestBot');
ok( scalar @errors > 0, 'Bot name is reserved' );
like( $errors[0], qr/illegal name/i, 'Error message for reserved name' );

@errors = DCBUser::user_invalid_name('Anonymous');
ok( scalar @errors > 0, 'Anonymous name is reserved' );

# Case insensitive check for reserved names
@errors = DCBUser::user_invalid_name('testbot');
ok( scalar @errors > 0, 'Bot name is reserved (case insensitive - lowercase)' );

@errors = DCBUser::user_invalid_name('TESTBOT');
ok( scalar @errors > 0, 'Bot name is reserved (case insensitive - uppercase)' );

@errors = DCBUser::user_invalid_name('anonymous');
ok( scalar @errors > 0, 'Anonymous is reserved (case insensitive - lowercase)' );

@errors = DCBUser::user_invalid_name('ANONYMOUS');
ok( scalar @errors > 0, 'Anonymous is reserved (case insensitive - uppercase)' );

# ---- Test user_check_errors ----
# A valid new user with no issues
my $valid_user = {
    name          => 'GoodUser',
    permission    => 8,
    connect_share => 1000,
    ip            => '127.0.0.1',
    client        => 'DC++ V:0.1',
    new           => 1,
};
@errors = user_check_errors($valid_user);
is( scalar @errors, 0, 'Valid new user has no errors' );

# An existing user (not new) bypasses name validation
my $existing_user = {
    name          => '<<<>>>',
    permission    => 8,
    connect_share => 1000,
    ip            => '127.0.0.1',
    client        => 'DC++ V:0.1',
    new           => 0,
};
@errors = user_check_errors($existing_user);
is( scalar @errors, 0, 'Existing user with bad name has no errors (name check skipped)' );

# New user with bad name gets errors
my $bad_name_user = {
    name          => '<<<>>>',
    permission    => 4,
    connect_share => 1000,
    ip            => '127.0.0.1',
    client        => 'DC++ V:0.1',
    new           => 1,
};
@errors = user_check_errors($bad_name_user);
ok( scalar @errors > 0, 'New user with invalid name gets errors' );

# Anon not allowed
{
    local $DCBSettings::config->{allow_anon} = 0;
    my $anon_user = {
        name          => 'SomeUser',
        permission    => 4,
        connect_share => 1000,
        ip            => '127.0.0.1',
        client        => 'DC++ V:0.1',
        new           => 0,
    };
    @errors = user_check_errors($anon_user);
    ok( scalar @errors > 0, 'Anonymous user rejected when allow_anon is 0' );
    like( $errors[0], qr/Registered users only/i, 'Error says registered users only' );
}

# Admin user bypasses all errors
my $admin_user = {
    name          => '<<<>>>',
    permission    => 32,
    connect_share => 0,
    ip            => '10.0.0.1',
    client        => 'M:P,H',
    new           => 1,
};
@errors = user_check_errors($admin_user);
is( scalar @errors, 0, 'Admin user bypasses all validation errors' );

# Operator user also bypasses errors
my $op_user = {
    name          => '<<<>>>',
    permission    => 16,
    connect_share => 0,
    ip            => '10.0.0.1',
    client        => 'M:P,H',
    new           => 1,
};
@errors = user_check_errors($op_user);
is( scalar @errors, 0, 'Operator user bypasses all validation errors' );

done_testing;
