package DCBUser;

use strict;
use warnings;
use DCBSettings;
use DCBDatabase;

use Data::Dumper;

use Exporter;
our @ISA= qw(Exporter);
our @EXPORT = qw(user_init user_load user_load_by_name user_load_by_mail user_update user_check_errors user_access user_permissions user_permissions_inherit user_connect user_disconnect user_is_admin PERMISSIONS);

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
sub user_load_by_mail($) {
  my $mail = shift;
  my %where = ('mail' => { -like => [$mail] });
  my @fields = ('*');
  my $userh = DCBDatabase::db_select('users', \@fields, \%where);

  # Send back the row as a ref hash array.
  # ie username is $user->{'name'}
  my $user = $userh->fetchrow_hashref();
  # If the user is new we must add their name to the returned hash
  $user->{'mail'} = $user->{'mail'} ? $user->{'mail'} : $mail;
  return $user;
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
  my %fields = (
    'ip' => $user->{ip},
    'permission' => $user->{permission},
    'connect_share' => $user->{connect_share},
    'connect_time' => $user->{connect_time},
    'client' => $user->{client},
  );

  if ($user->{new}) {
    $fields{'name'} = $user->{name},
    $fields{'mail'} = $user->{mail},
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

sub user_update($ $) {
  my $user = shift;
  my $fields = shift;

  my %where = ( 'uid' => $user->{'uid'} );
  DCBDatabase::db_update('users', $fields, \%where);
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
    push(@errors, "Your share is currently under the minimum share. The minimum share is currently " . DCBCommon::common_format_size($DCBSettings::config->{minshare}));
  }
  if (!$DCBSettings::config->{allow_external} && $user->{'ip'} !~ 127.0.0.1) {
    push(@errors, "External users are not currently accepted.");
  }
  if (!$DCBSettings::config->{allow_passive} && $user->{'client'} =~ /M:P,H/) {
    push(@errors, "Passive users are not currently accepted.");
  }
  # If we're dealing with an op/op-admin then disregard all errors
  if (user_is_admin($user)) {
    @errors = ();
  }

  return @errors;
}

sub user_invalid_name($) {
  my $name = shift;
  my @errors = ();
  if (length($name) > $DCBSettings::config->{username_max_length}) {
    push(@errors, "Name length exceeds maximum of $DCBSettings::config->{username_max_length}");
  }
  if (($name !~ /[\w-]+/) || ($name =~ /[\\\/]/)) {
    push(@errors, "Name contains illegal characters. Letters, numbers, underscores and hyphens only.");
  }
  if (lc($name) eq lc($DCBSettings::config->{botname}) || lc($name) eq lc($DCBSettings::config->{username_anonymous})) {
    push(@errors, "An illegal name has been chosen please use another.");
  }
  return @errors;
}

sub user_is_admin {
  my $user = shift;
  if ($user->{'permission'} >= 16) {
    return 1;
  }
  return 0;
}

1;
