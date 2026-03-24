package seen;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;
use DCBDatabase;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  $chat =~ s/^\s+|\s+$//g;

  if (!$chat) {
    return ({
      param   => "message",
      message => "Usage: -seen <username>",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $target_name = $chat;

  # Check if user is currently online
  if ($DCBUser::userlist->{lc($target_name)}) {
    my $target = $DCBUser::userlist->{lc($target_name)};
    if (!$target->{disconnect_time} || $target->{connect_time} > $target->{disconnect_time}) {
      my $duration = DCBCommon::common_timestamp_duration($target->{connect_time});
      return ({
        param   => "message",
        message => "$target->{name} is ONLINE right now! (connected $duration ago)",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
    }
  }

  # Look up in database
  my $target = DCBUser::user_load_by_name($target_name);
  if ($target && $target->{uid}) {
    if ($target->{disconnect_time}) {
      my $last_seen = DCBCommon::common_timestamp_time($target->{disconnect_time});
      my $duration = DCBCommon::common_timestamp_duration($target->{disconnect_time});
      return ({
        param   => "message",
        message => "$target->{name} was last seen $duration ago ($last_seen)",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
    }
    else {
      return ({
        param   => "message",
        message => "$target->{name} exists but has no disconnect record.",
        user    => $user->{name},
        touser  => '',
        type    => MESSAGE->{'PUBLIC_SINGLE'},
      });
    }
  }
  else {
    return ({
      param   => "message",
      message => "Never heard of '$target_name'.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }
}

1;
