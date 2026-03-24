use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/lib";
use MockODCH;

# ---- Test that mock odch:: namespace is functional ----

# Test data_to_all
odch::data_to_all('Hello everyone!');
is( scalar @odch::sent_to_all, 1, 'data_to_all records one message' );
is( $odch::sent_to_all[0], 'Hello everyone!', 'data_to_all message content correct' );

odch::data_to_all('Second message');
is( scalar @odch::sent_to_all, 2, 'data_to_all records second message' );

# Test data_to_user
odch::data_to_user( 'Hello user!', 'TestUser' );
is( scalar @odch::sent_to_user, 1, 'data_to_user records one message' );
is( $odch::sent_to_user[0][0], 'Hello user!', 'data_to_user message content correct' );
is( $odch::sent_to_user[0][1], 'TestUser',    'data_to_user target user correct' );

# Test kick_user
odch::kick_user('BadUser');
is( scalar @odch::kicked_users, 1, 'kick_user records one kick' );
is( $odch::kicked_users[0], 'BadUser', 'kick_user target correct' );

# Test get_ip with default
is( odch::get_ip('anyone'), '192.168.1.1', 'get_ip returns default IP' );

# Test get_ip with custom user data
$odch::user_data{CustomUser} = { ip => '10.0.0.1' };
is( odch::get_ip('CustomUser'), '10.0.0.1', 'get_ip returns custom IP' );

# Test get_share
is( odch::get_share('anyone'), 10000000000, 'get_share returns default share' );

# Test get_variable
is( odch::get_variable('hub_name'), 'TestHub', 'get_variable returns hub_name' );
is( odch::get_variable('total_share'), 1000000, 'get_variable returns total_share' );
is( odch::get_variable('nonexistent'), '', 'get_variable returns empty for missing' );

# Test set_variable
odch::set_variable( 'custom_var', 42 );
is( odch::get_variable('custom_var'), 42, 'set_variable/get_variable roundtrip works' );

# Test count_users
is( odch::count_users(), 5, 'count_users returns default 5' );

# Test register_script_name
odch::register_script_name('MyBot');
is( $odch::registered_name, 'MyBot', 'register_script_name records name' );

# Test gag functions
odch::add_gag_entry('SpamUser');
is( scalar @odch::gagged, 1, 'add_gag_entry adds user' );
is( $odch::gagged[0], 'SpamUser', 'Gagged user is correct' );

odch::add_gag_entry('AnotherSpammer');
is( scalar @odch::gagged, 2, 'Second gag adds user' );

odch::remove_gag_entry('SpamUser');
is( scalar @odch::gagged, 1, 'remove_gag_entry removes user' );
is( $odch::gagged[0], 'AnotherSpammer', 'Correct user remains gagged' );

# Test nickban functions
odch::add_nickban_entry('BannedNick');
is( scalar @odch::nickbanned, 1, 'add_nickban_entry adds nick' );

odch::remove_nickban_entry('BannedNick');
is( scalar @odch::nickbanned, 0, 'remove_nickban_entry removes nick' );

# Test check functions
is( odch::check_if_banned('anyone'),    0, 'check_if_banned returns 0 (not banned)' );
is( odch::check_if_allowed('anyone'),   1, 'check_if_allowed returns 1 (allowed)' );
is( odch::check_if_registered('anyone'), 0, 'check_if_registered returns 0 (not registered)' );

# Test get functions with defaults
is( odch::get_description('anyone'), 'TestClient V:0.1',  'get_description default' );
is( odch::get_type('anyone'),        4,                    'get_type default' );
is( odch::get_hostname('anyone'),    'test.example.com',   'get_hostname default' );
is( odch::get_version('anyone'),     '0.1',                'get_version default' );
is( odch::get_email('anyone'),       'test@example.com',   'get_email default' );
is( odch::get_connection('anyone'),  1,                    'get_connection default' );
is( odch::get_flag('anyone'),        0,                    'get_flag default' );
is( odch::get_user_list(),           '',                   'get_user_list default empty' );

# Test reset_mock
odch::reset_mock();
is( scalar @odch::sent_to_all,  0, 'reset_mock clears sent_to_all' );
is( scalar @odch::sent_to_user, 0, 'reset_mock clears sent_to_user' );
is( scalar @odch::kicked_users, 0, 'reset_mock clears kicked_users' );
is( scalar @odch::gagged,       0, 'reset_mock clears gagged' );
is( scalar @odch::nickbanned,   0, 'reset_mock clears nickbanned' );
is( odch::get_variable('hub_name'), 'TestHub', 'reset_mock restores default variables' );
is( odch::get_ip('CustomUser'), '192.168.1.1', 'reset_mock clears custom user_data' );

done_testing;
