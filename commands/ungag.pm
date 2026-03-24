package ungag;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my @chatarray = split(/\s+/, shift);
  my $victimname = @chatarray ? shift(@chatarray) : '';
  my $botmessage = '';
  my @return = ();

  if (!$victimname) {
    $botmessage = "Usage: " . DCBSettings::config_get('cp') . "ungag <username>";
  }
  else {
    my $victim = $DCBUser::userlist->{lc($victimname)};
    if ($victim && $victim->{uid}) {
      $botmessage = "$user->{name} has ungagged $victimname";

      @return = (
        {
          param   => "message",
          message => $botmessage,
          user    => $victim->{name},
          touser  => '',
          type    => MESSAGE->{'PUBLIC_ALL'},
        },
        {
          param  => "action",
          user   => $victim->{name},
          action => 'ungag',
        },
        {
          param  => "log",
          action => "ungag",
          arg    => $botmessage,
          user   => $user,
        },
      );
      return @return;
    }
    else {
      $botmessage = "User does not exist or is offline.";
    }
  }

  @return = (
    {
      param   => "message",
      message => $botmessage,
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

1;
