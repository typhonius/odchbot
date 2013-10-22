package info;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw(first);
use DCBCommon;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();

  # Check user permissions to determine what we should return.
  my @chatarray = split(/\s+/, $chat);
  my $info_user = @chatarray ? lc(shift(@chatarray)) : lc($user->{'name'});
  my $message = DCBSettings::config_get('no_perms');

  my $target = exists($DCBUser::userlist->{$info_user}) ? $DCBUser::userlist->{$info_user} : '';

  if ($target) {
    if ($info_user =~ $user->{'name'} || user_access($user, DCBUser::PERMISSIONS->{ADMINISTRATOR})
      || user_access($user, DCBUser::PERMISSIONS->{OPERATOR})) {

      my $permissions = DCBUser::PERMISSIONS;
      my %perm = %{$permissions};
      my $perm = 'UNKNOWN';
      foreach my $val (keys %perm) {
        if ($perm{$val} == $target->{permission}) {
          $perm = $val;
        }
      }

      $message = "Info for " . $target->{name};
      $message .= "\nUID: " . $target->{uid};
      $message .= "\nJoined: " . DCBCommon::common_timestamp_time($target->{join_time});
      $message .= "\nConnected: " . DCBCommon::common_timestamp_time($target->{connect_time});
      # Brand new users will not have a disconnect time so omit that if one is not present.
      if ($target->{disconnect_time}) {
        $message .= "\nDisconnected: " . DCBCommon::common_timestamp_time($target->{disconnect_time});
      }
      $message .= "\nFirst Share: " . DCBCommon::common_format_size($target->{join_share});
      $message .= "\nRecent Share: " . DCBCommon::common_format_size($target->{connect_share});
      $message .= "\nShare Difference: " . DCBCommon::common_format_size($target->{connect_share} - $target->{join_share});
      $message .= "\nPermission: " . $perm;
      $message .= "\nClient: " . $target->{client};
      $message .= "\nStatus: " . (!$target->{disconnect_time} || $target->{connect_time} > $target->{disconnect_time} ? "Online for: " . DCBCommon::common_timestamp_duration($target->{connect_time}) : "Offline");
    }
    else {
      # Limited
      $message = "Info for " . $target->{name};
      $message .= "\nJoined: " . DCBCommon::common_timestamp_time($target->{join_time});
      $message .= "\nShare Difference: " . DCBCommon::common_format_size($target->{connect_share} - $target->{join_share});
      $message .= "\nClient: " . $target->{client};
      $message .= "\nStatus: " . ($target->{connect_time} > $target->{disconnect_time} ? "Online for: " . DCBCommon::common_timestamp_duration($target->{connect_time}) : "Offline");
    }
  }
  else {
    $message = "User does not exist currently";
  }

  @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{PUBLIC_SINGLE},
    },
  );
  return @return;
}

1;
