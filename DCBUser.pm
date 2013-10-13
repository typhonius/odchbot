package DCBUser;

use strict;
use warnings;
use DCBSettings;
use DCBDatabase;

use Exporter;
our @ISA= qw(Exporter);
our @EXPORT = qw(user_init user_load user_load_by_name user_check_errors user_access user_permissions user_permissions_inherit user_connect user_disconnect);

use constant PERMISSIONS => {
  OFFLINE        => 0,
  KEY_NOT_SENT   => 1,
  KEY_SENT       => 2,
  ANONYMOUS      => 4,
  AUTHENTICATED  => 8,
  OPERATOR       => 16,
  ADMINISTRATOR  => 32,
  TELNET         => 64,
};

sub new { bless {}, shift }

sub user_init() {
  my @user_list = @_;
  my @online = ();
  foreach (split(/\s+/, $user_list[1])) {
    push(@online, $_);
  }
  user_sanitize_disconnects(\@online);
  our $userlist = ();
  my $userh = DCBDatabase::db_select('users');
  while (my $user = $userh->fetchrow_hashref()) {
    $userlist->{lc($user->{name})} = $user;
  }
}

# Whenever we're dealing with logins or logouts we need the user data from the database.
sub user_load_by_name($) {
  my $name = shift;
  my %where = ('name' => { -like => [$name] });
  my @fields = ('*');
  my $userh = DCBDatabase::db_select('users', \@fields, \%where);

  # Send back the row as a ref hash array.
  # ie username is $user->{'name'}
  my $user = $userh->fetchrow_hashref();
  # If the user is new we must add their name to the returned hash
  $user->{'name'} = $user->{'name'} ? $user->{'name'} : $name;
  return $user;
}

sub user_load($) {
  my $uid = shift;
  my %where = ('uid' => $uid);
  my @fields = ('*');
  my $userh = DCBDatabase::db_select('users', \@fields, \%where);

  # Send back the row as a ref hash array.
  # ie username is $user->{'name'}
  my $user = $userh->fetchrow_hashref();
  return $user;
}

sub user_connect($) {
  my $user = shift;
  # can we just insert all fields k/v style?
  my %fields = (
    'ip' => $user->{ip},
    'permission' => $user->{permission},
    'connect_share' => $user->{connect_share},
    'connect_time' => $user->{connect_time},
    'client' => $user->{client},
  );

  if ($user->{new}) {
    $fields{'name'} = $user->{name},
    $fields{'join_time'} = $user->{join_time};
    $fields{'join_share'} = $user->{join_share};
    $fields{'disconnect_time'} = 0;
    DCBDatabase::db_insert('users', \%fields);
    # We need to get uid of new user for commands
    my @fields = ( 'uid' );
    my %where = ( 'name' => $fields{'name'} );
    my $uidh = DCBDatabase::db_select('users', \@fields, \%where, \(), 1);
    $user->{uid} = $uidh->fetchrow_array();
  }
  else {
    my %where = ('uid' => $user->{uid});
    DCBDatabase::db_update('users', \%fields, \%where);
  }
}

sub user_disconnect($) {
  my $user = shift;
  my %fields = (
    'disconnect_time' => $user->{disconnect_time},
  );
  my %where = ('uid' => $user->{uid});
  DCBDatabase::db_update('users', \%fields, \%where);
}

sub user_sanitize_disconnects {
  my $online = shift;
  my %fields = ('disconnect_time' => time());
  my %where = ( name => { -not_in => $online } );
  DCBDatabase::db_update('users', \%fields, \%where);
}

sub user_permissions( @ ) {
  my (@permissions) = @_;
  my $return = 0;

  # Convert strings of permission names to their integer
  my @bits = map { PERMISSIONS->{$_} } @permissions;

  for (my $i = 0; $i < scalar(@bits); $i++) {
    $return |= $bits[$i];
  }

   return $return;
 }

sub user_permissions_inherit() {
  my $permission = shift;
  # Takes a permission and makes it so any underneath inherit permissions
  return ~($permission << 1);
}

sub user_access {
  my $user = shift;
  my $permission = shift;
  return ($user->{permission} & $permission) ? 1 : 0;
}
 
sub user_check_errors($) {
  my $user = shift;
  my @errors = ();

  if ($user->{'permission'} <= 4 && !$DCBSettings::config->{allow_anon}) {
    push(@errors, "Registered users only");
  }
  my @name_errors = user_invalid_name($user->{'name'});
  if (@name_errors && $user->{'new'}) {
    push(@errors, "Your username is invalid, please change it.");
    push(@errors, @name_errors);
  }
  if ($DCBSettings::config->{minshare} > $user->{'connect_share'}) {
    push(@errors, "Your share is currently under the minimum share.");
  }
  if (!$DCBSettings::config->{allow_external} && $user->{'ip'} !~ 127.0.0.1) {
    push(@errors, "External users are not currently accepted.");
  }
  if (!$DCBSettings::config->{allow_passive} && $user->{'connection_type'} =~ /passive/) {
    push(@errors, "Passive users are not currently accepted.");
  }

  return @errors;
}

sub user_invalid_name($) {
  my $name = shift;
  my @errors = ();
  if (length($name) > $DCBSettings::config->{username_max_length}) {
    push(@errors, "Name length exceeds maximum of $DCBSettings::config->{username_max_length}");
  }
  return @errors;
}

sub user_valid_name_regex($) {
  # perhaps use this function or a $config for regex to display to the user (A-Z a-z 0-9 _ I think would be good)
}
#TODO
# disallow the Anonymous username and the bot username

#   $login = 0;
#   my ($namecheck_user) = @_;
#
#   elsif ($namecheck_user =~ /unconfigured-valknut-client/i) {
#     $pm .= "$user, Please configure your username as per the instructions here: http://chaoticneutral.ath.cx/faq/mac-name.html\n";
#   }
#   elsif ($namecheck_user =~ /.*\W.*/ || $namecheck_user =~ /.*\W.*/) {
#     $pm .= "Your name is $user, Please remove all disallowed characters from your username\n\nAllowed characters:\n * Letters\n * Numbers\n * Underscores\n";
#   }
#   elsif ($namecheck_user =~ /.*\/.*/ || $namecheck_user =~ /.*\\.*/) {
#     $pm .= "Please remove all slashes from your username.\n";
#   }
#   elsif (length($namecheck_user) < $config{min_username}) {
#     $pm .= "Please ensure your name is longer than " . $config{min_username} . " characters then attempt to log on again.";
#   }
#   else{
#     $login = 1;
#   }
#   return $login;
# }

# if ($user_perm == 0 && namecheck($user) == 1) {
#   $login = 1;
# }
# if ($user_perm >= 1) {
#   $login = 1;
# }
# if ($user_perm > 1 && $config{opgreetingon}) {
#   $public = $config{opgreeting} . " " . $user;
# }
# if ($user_perm <= 1 && $user_share <= 0) {
#   $login = 1;
# #if ($user_perm <= 1 && $Config{usergreetingon}) {
# #  $public = $Config{usergreeting} . " " . $user;
# #}

1;
