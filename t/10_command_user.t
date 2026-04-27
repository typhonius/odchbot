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

# Ensure user_op_login_notify config is set
$DCBSettings::config->{user_op_login_notify} = 1;
$DCBSettings::config->{user_op_login_notify_message} = 'Welcome online';

use DCBDatabase;
use DCBCommon;
use DCBUser;

# Connect and install base tables
DCBDatabase::db_connect();
DCBDatabase::db_install();

# Load user command
use user;

# ---- Test postlogin for new user ----
my $new_user = {
    uid             => 100,
    name            => 'NewUser',
    permission      => 4,
    new             => 1,
    join_time       => time() - 100,
    join_share      => 1000000,
    connect_share   => 1500000,
    connect_time    => time(),
    client          => 'DC++ 0.8',
};

my @result = user::postlogin(undef, $new_user);
ok( scalar @result >= 2, 'New user postlogin returns multiple actions' );

# First message should be PUBLIC_ALL welcome
my @public_all = grep { $_->{type} == MESSAGE->{'PUBLIC_ALL'} && $_->{param} eq 'message' } @result;
ok( scalar @public_all >= 1, 'New user gets PUBLIC_ALL message' );
like( $public_all[0]->{message}, qr/Welcome to .* for the first time.*NewUser/, 'First-time welcome message' );

# Should also get a HUB_PM welcome info box
my @hub_pm = grep { $_->{type} == MESSAGE->{'HUB_PM'} && $_->{param} eq 'message' } @result;
ok( scalar @hub_pm >= 1, 'New user gets HUB_PM welcome info box' );
like( $hub_pm[0]->{message}, qr/NewUser/, 'Welcome info contains username' );

# ---- Test postlogin for returning user ----
my $returning_user = {
    uid             => 101,
    name            => 'ReturningUser',
    permission      => 8,
    new             => 0,
    join_time       => time() - 86400 * 30,
    join_share      => 5000000,
    connect_share   => 10000000,
    connect_time    => time(),
    client          => 'DC++ 0.8',
};

@result = user::postlogin(undef, $returning_user);
ok( scalar @result >= 2, 'Returning user postlogin returns multiple actions' );

# First message should be PUBLIC_SINGLE welcome back
my @public_single = grep { $_->{type} == MESSAGE->{'PUBLIC_SINGLE'} && $_->{param} eq 'message' } @result;
ok( scalar @public_single >= 1, 'Returning user gets PUBLIC_SINGLE message' );
like( $public_single[0]->{message}, qr/Welcome back.*ReturningUser/, 'Welcome back message' );

# ---- Test op notification ----
my $op_user = {
    uid             => 102,
    name            => 'OpUser',
    permission      => 16,
    new             => 0,
    join_time       => time() - 86400 * 365,
    join_share      => 100000000,
    connect_share   => 200000000,
    connect_time    => time(),
    client          => 'DC++ 0.8',
};

@result = user::postlogin(undef, $op_user);

# Op user should get an additional PUBLIC_ALL notification
@public_all = grep { $_->{type} == MESSAGE->{'PUBLIC_ALL'} && $_->{param} eq 'message' } @result;
ok( scalar @public_all >= 1, 'Op gets PUBLIC_ALL notification' );
my @op_notifs = grep { $_->{message} =~ /Welcome online/ } @public_all;
ok( scalar @op_notifs >= 1, 'Op notification contains configured message' );

# ---- Test welcome info box content ----
@hub_pm = grep { $_->{type} == MESSAGE->{'HUB_PM'} && $_->{param} eq 'message' } @result;
ok( scalar @hub_pm >= 1, 'Op gets HUB_PM welcome info box' );
like( $hub_pm[0]->{message}, qr/OPERATOR/, 'Welcome info shows permission level' );
like( $hub_pm[0]->{message}, qr/Member for:/, 'Welcome info shows member duration' );
like( $hub_pm[0]->{message}, qr/Share delta:/, 'Welcome info shows share delta' );

# ---- Test op notification disabled ----
$DCBSettings::config->{user_op_login_notify} = 0;
@result = user::postlogin(undef, $op_user);
@public_all = grep { $_->{type} == MESSAGE->{'PUBLIC_ALL'} && $_->{param} eq 'message' } @result;
my @disabled_notifs = grep { $_->{message} =~ /Welcome online/ } @public_all;
is( scalar @disabled_notifs, 0, 'No op notification when disabled' );

done_testing;
