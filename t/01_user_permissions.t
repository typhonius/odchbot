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

# ---- Test PERMISSIONS constant ----
is( PERMISSIONS->{OFFLINE},       0,  'OFFLINE permission is 0' );
is( PERMISSIONS->{KEY_NOT_SENT},  1,  'KEY_NOT_SENT permission is 1' );
is( PERMISSIONS->{KEY_SENT},      2,  'KEY_SENT permission is 2' );
is( PERMISSIONS->{ANONYMOUS},     4,  'ANONYMOUS permission is 4' );
is( PERMISSIONS->{AUTHENTICATED}, 8,  'AUTHENTICATED permission is 8' );
is( PERMISSIONS->{OPERATOR},      16, 'OPERATOR permission is 16' );
is( PERMISSIONS->{ADMINISTRATOR}, 32, 'ADMINISTRATOR permission is 32' );
is( PERMISSIONS->{TELNET},        64, 'TELNET permission is 64' );

# ---- Test user_permissions - combining multiple permissions ----
my $perm = user_permissions('ANONYMOUS', 'AUTHENTICATED');
is( $perm, 12, 'Combined ANONYMOUS + AUTHENTICATED = 12 (4|8)' );

$perm = user_permissions('OPERATOR', 'ADMINISTRATOR');
is( $perm, 48, 'Combined OPERATOR + ADMINISTRATOR = 48 (16|32)' );

$perm = user_permissions('ANONYMOUS');
is( $perm, 4, 'Single ANONYMOUS = 4' );

$perm = user_permissions('OFFLINE');
is( $perm, 0, 'Single OFFLINE = 0' );

$perm = user_permissions( 'ANONYMOUS', 'AUTHENTICATED', 'OPERATOR', 'ADMINISTRATOR' );
is( $perm, 60, 'All mid-range permissions = 60 (4|8|16|32)' );

# Idempotent - combining same permission twice
$perm = user_permissions( 'OPERATOR', 'OPERATOR' );
is( $perm, 16, 'Combining OPERATOR with itself = 16 (bitwise OR is idempotent)' );

# ---- Test user_access ----
my $admin_user = { permission => 32 };
my $op_user    = { permission => 16 };
my $reg_user   = { permission => 8 };
my $anon_user  = { permission => 4 };
my $multi_user = { permission => 48 };    # OPERATOR | ADMINISTRATOR

ok( user_access( $admin_user, PERMISSIONS->{ADMINISTRATOR} ), 'Admin has ADMINISTRATOR access' );
ok( user_access( $op_user,    PERMISSIONS->{OPERATOR} ),      'Op has OPERATOR access' );
ok( user_access( $reg_user,   PERMISSIONS->{AUTHENTICATED} ), 'Reg user has AUTHENTICATED access' );
ok( user_access( $anon_user,  PERMISSIONS->{ANONYMOUS} ),     'Anon has ANONYMOUS access' );

ok( !user_access( $reg_user,  PERMISSIONS->{OPERATOR} ),      'Regular user does NOT have OPERATOR access' );
ok( !user_access( $anon_user, PERMISSIONS->{ADMINISTRATOR} ), 'Anon does NOT have ADMIN access' );
ok( !user_access( $anon_user, PERMISSIONS->{AUTHENTICATED} ), 'Anon does NOT have AUTHENTICATED access' );

# Multi-permission user
ok( user_access( $multi_user, PERMISSIONS->{OPERATOR} ),      'Multi-perm user has OPERATOR access' );
ok( user_access( $multi_user, PERMISSIONS->{ADMINISTRATOR} ), 'Multi-perm user has ADMINISTRATOR access' );
ok( !user_access( $multi_user, PERMISSIONS->{ANONYMOUS} ),    'Multi-perm user does NOT have ANONYMOUS access' );

# ---- Test user_is_admin ----
ok( user_is_admin($admin_user), 'Admin user (32) is admin' );
ok( user_is_admin($op_user),    'Op user (16) is admin' );
ok( user_is_admin($multi_user), 'Multi-perm user (48) is admin' );
ok( !user_is_admin($reg_user),  'Regular user (8) is not admin' );
ok( !user_is_admin($anon_user), 'Anonymous user (4) is not admin' );

# Edge case: TELNET (64) is also admin since >= 16
my $telnet_user = { permission => 64 };
ok( user_is_admin($telnet_user), 'Telnet user (64) is admin (>= 16)' );

# Edge case: permission 0 (OFFLINE)
my $offline_user = { permission => 0 };
ok( !user_is_admin($offline_user), 'Offline user (0) is not admin' );

done_testing;
