package seen;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBDatabase;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @chatarray = split(/\s+/, $chat);
  my $target_name = shift(@chatarray);
  my $message = '';

  if (!$target_name) {
    $message = "Usage: " . DCBSettings::config_get('cp') . "seen <username>";
  }
  else {
    # Check if user is currently online
    my $online_user = $DCBUser::userlist->{lc($target_name)};
    if ($online_user && $online_user->{connect_time} &&
        (!$online_user->{disconnect_time} || $online_user->{connect_time} > $online_user->{disconnect_time})) {
      my $duration = DCBCommon::common_timestamp_duration($online_user->{connect_time});
      $message = "$target_name is currently online (connected $duration ago)";
    }
    else {
      # Look up in database
      my $db_user = DCBUser::user_load_by_name($target_name);
      if ($db_user && $db_user->{uid}) {
        if ($db_user->{disconnect_time}) {
          my $last_seen = DCBCommon::common_timestamp_time($db_user->{disconnect_time});
          my $duration = DCBCommon::common_timestamp_duration($db_user->{disconnect_time});
          $message = "$target_name was last seen $duration ago ($last_seen)";
        }
        elsif ($db_user->{connect_time}) {
          my $last_seen = DCBCommon::common_timestamp_time($db_user->{connect_time});
          $message = "$target_name was last seen connecting at $last_seen";
        }
        else {
          $message = "$target_name exists but has no activity records";
        }
      }
      else {
        $message = "I have never seen $target_name";
      }
    }
  }

  my @return = (
    {
      param   => "message",
      message => $message,
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

1;
