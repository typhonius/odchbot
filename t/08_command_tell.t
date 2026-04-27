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
use DCBUser;

# Connect and install base tables
DCBDatabase::db_connect();
DCBDatabase::db_install();

# Load tell command and install its schema
use tell;
my $schema = tell::schema();
DCBDatabase::db_create_table($schema);

# Create test users in database
my %sender_db = (
    name            => 'Sender',
    mail            => 'sender@test.com',
    permission      => 8,
    join_time       => 1000000,
    connect_time    => time(),
    disconnect_time => 0,
);
DCBDatabase::db_insert('users', \%sender_db);
my $sth = DCBDatabase::db_select('users', ['uid'], {name => 'Sender'});
my $sender_uid = ($sth->fetchrow_array())[0];

my %receiver_db = (
    name            => 'Receiver',
    mail            => 'receiver@test.com',
    permission      => 4,
    join_time       => 1000000,
    connect_time    => time() - 1000,
    disconnect_time => time() - 500,
);
DCBDatabase::db_insert('users', \%receiver_db);
$sth = DCBDatabase::db_select('users', ['uid'], {name => 'Receiver'});
my $receiver_uid = ($sth->fetchrow_array())[0];

my $sender   = { uid => $sender_uid, name => 'Sender', permission => 8 };
my $receiver = { uid => $receiver_uid, name => 'Receiver', permission => 4 };

# ---- Test init ----
tell::init();
ok( defined $DCBCommon::COMMON->{tell}->{pending_uids}, 'init creates pending_uids hash' );
is( scalar keys %{$DCBCommon::COMMON->{tell}->{pending_uids}}, 0, 'pending_uids starts empty' );

# ---- Test main with no user specified ----
my @result = tell::main(undef, $sender, '');
is( scalar @result, 1, 'No user returns one message' );
like( $result[0]->{message}, qr/No user specified/, 'Error about no user' );

# ---- Test main with non-existent user ----
@result = tell::main(undef, $sender, 'NonExistent Hello there');
is( scalar @result, 1, 'Non-existent user returns one message' );
like( $result[0]->{message}, qr/not a user/, 'Error about non-existent user' );

# ---- Test main with valid user ----
@result = tell::main(undef, $sender, 'Receiver Hello from sender!');
is( scalar @result, 1, 'Valid tell returns one message' );
like( $result[0]->{message}, qr/Message from Sender to Receiver saved/, 'Confirmation message' );
like( $result[0]->{message}, qr/log on/, 'Says next time they log on (user is offline)' );
is( $result[0]->{type}, MESSAGE->{'PUBLIC_ALL'}, 'Message type is PUBLIC_ALL' );

# Check that tell was cached in memory
is( $DCBCommon::COMMON->{tell}->{pending_uids}->{$receiver_uid}, 1, 'Tell cached in pending_uids' );

# ---- Test tell_check_tells ----
is( tell::tell_check_tells($receiver), 1, 'tell_check_tells returns 1 when tells pending' );
is( tell::tell_check_tells($sender), 0, 'tell_check_tells returns 0 when no tells' );

# ---- Test tell_get_tells ----
my $tells = tell::tell_get_tells($receiver);
like( $tells, qr/Receiver you have received the following messages/, 'Tells header present' );
like( $tells, qr/Sender said: Hello from sender!/, 'Tell message content present' );

# Check cache cleared after delivery
ok( !$DCBCommon::COMMON->{tell}->{pending_uids}->{$receiver_uid}, 'pending_uids cleared after delivery' );

# Check DB cleaned up
$sth = DCBDatabase::db_select('tell', ['tid'], {to_uid => $receiver_uid});
ok( !$sth->fetchrow_array(), 'Tell records deleted from DB after delivery' );

# ---- Test tell_check_tells returns 0 after delivery ----
is( tell::tell_check_tells($receiver), 0, 'tell_check_tells returns 0 after tells delivered' );

# ---- Test postlogin hook delivers tells ----
# Send another tell
tell::main(undef, $sender, 'Receiver Second message');

@result = tell::postlogin(undef, $receiver);
ok( scalar @result > 0, 'postlogin delivers pending tells' );
my @msgs = grep { $_->{param} eq 'message' } @result;
ok( scalar @msgs >= 1, 'postlogin returns messages' );
like( $msgs[0]->{message}, qr/Second message/, 'postlogin delivers the tell content' );

# ---- Test line hook delivers tells ----
tell::main(undef, $sender, 'Receiver Third message');
@result = tell::line(undef, $receiver);
ok( scalar @result > 0, 'line hook delivers pending tells' );

done_testing;
