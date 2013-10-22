package user;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBDatabase;
use DCBCommon;
use DCBUser;

sub schema {
  my %schema = (
    config => {
      user_op_login_notify => 1,
      user_op_login_notify_message => "Welcome online",
    },
  );
  return \%schema;
}

sub postlogin {
  my $command = shift;
  my $user = shift;
  my @return = ();
  my $hubname = DCBSettings::config_get('hubname');
  if ($user->{new}) {
    @return = (
      {
        param    => "message",
        message  => "Welcome to $hubname for the first time: $user->{name}",
        user     => '',
        fromuser   => '',
        type     => MESSAGE->{'PUBLIC_ALL'},
      },
    );
  }
  else {
    @return = (
      {
        param    => "message",
        message  => "Welcome back to $hubname $user->{name}",
        user     => $user->{name},
        fromuser   => '',
        type     => MESSAGE->{'PUBLIC_SINGLE'},
      },
    );
  }
  # Allow Ops/Op-admin users to be shown to enter
  if ($user->{permission} >= 16  && $DCBSettings::config->{user_op_login_notify}) {
    my @op_notify = (
      {
        param    => "message",
        message  => $DCBSettings::config->{user_op_login_notify_message} . " $user->{name}",
        user     => $user->{name},
        fromuser   => '',
        type     => MESSAGE->{'PUBLIC_ALL'},
      },
    );
    push(@return, @op_notify);
  }

  # Provide the user with additional welcome information
  my $permissions = PERMISSIONS;
  my %perm = %{$permissions};
  my $perm = 'UNKNOWN';
  foreach my $val (keys %perm) {
    if ($perm{$val} == $user->{permission}) {
      $perm = $val;
    }
  }

  my $member_time = DCBCommon::common_timestamp_duration($user->{'join_time'});
  my $share_delta = DCBCommon::common_format_size($user->{'connect_share'} - $user->{'join_share'});

  my $welcome = "\n" . ('-' x 70) . "\n";
  $welcome .= "***===[ $user->{'name'} :: $perm :: $user->{'client'} ]===***\n***===[ Member for: $member_time :: Share delta: $share_delta ]===***\n";
  $welcome .= '-' x 70;

  my @login = (
    {
      param    => "message",
      message  => $welcome,
      user     => $user->{name},
      fromuser   => '',
      type     => MESSAGE->{'PUBLIC_SINGLE'},
    },
  );
  # TODO change the type here to be sent from the hub perhaps?

  push(@return, @login);

  return @return;
}

sub prelogin {
  my $command = shift;
  my $user = shift;
  return;
}

sub logout {

}

1;