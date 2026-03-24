package odch;

use strict;
use warnings;

our @sent_to_all    = ();
our @sent_to_user   = ();
our @kicked_users   = ();
our @gagged         = ();
our @nickbanned     = ();
our %variables      = ( total_share => 1000000, hub_name => 'TestHub' );
our %user_data      = ();
our $user_count     = 5;
our $user_list      = '';
our $registered_name = '';

sub reset_mock {
    @sent_to_all    = ();
    @sent_to_user   = ();
    @kicked_users   = ();
    @gagged         = ();
    @nickbanned     = ();
    $user_count     = 5;
    $user_list      = '';
    $registered_name = '';
    %user_data      = ();
    %variables      = ( total_share => 1000000, hub_name => 'TestHub' );
}

sub data_to_all          { push @sent_to_all, $_[0]; }
sub data_to_user         { push @sent_to_user, [ $_[0], $_[1] ]; }
sub kick_user            { push @kicked_users, $_[0]; }
sub get_ip               { return $user_data{ $_[0] }{ip}          // '192.168.1.1'; }
sub get_share            { return $user_data{ $_[0] }{share}       // 10000000000; }
sub get_description      { return $user_data{ $_[0] }{description} // 'TestClient V:0.1'; }
sub get_variable         { return $variables{ $_[0] }              // ''; }
sub get_type             { return $user_data{ $_[0] }{type}        // 4; }
sub get_hostname         { return $user_data{ $_[0] }{hostname}    // 'test.example.com'; }
sub get_version          { return $user_data{ $_[0] }{version}     // '0.1'; }
sub get_email            { return $user_data{ $_[0] }{email}       // 'test@example.com'; }
sub get_connection       { return $user_data{ $_[0] }{connection}  // 1; }
sub get_flag             { return $user_data{ $_[0] }{flag}        // 0; }
sub get_user_list        { return $user_list; }
sub count_users          { return $user_count; }
sub register_script_name { $registered_name = $_[0]; }
sub add_gag_entry        { push @gagged, $_[0]; }
sub remove_gag_entry     { @gagged = grep { $_ ne $_[0] } @gagged; }
sub add_nickban_entry    { push @nickbanned, $_[0]; }
sub remove_nickban_entry { @nickbanned = grep { $_ ne $_[0] } @nickbanned; }
sub add_ban_entry        { }
sub remove_ban_entry     { }
sub add_allow_entry      { }
sub remove_allow_entry   { }
sub add_reg_user         { }
sub remove_reg_user      { }
sub force_move_user      { }
sub set_variable         { $variables{ $_[0] } = $_[1]; }
sub check_if_banned      { return 0; }
sub check_if_allowed     { return 1; }
sub check_if_registered  { return 0; }
sub add_linked_hub       { }
sub remove_linked_hub    { }

1;
