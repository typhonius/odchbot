package gag;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;

sub schema {
  my %schema = (
    config => {
      gag_default_time => 300,
      gag_default_message => "You have been gagged",
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $botmessage = '';
  my @return = ();
  my @chatarray = split(/\s+/, shift);

  if (!@chatarray) {
    $botmessage = "Usage: " . DCBSettings::config_get('cp') . "gag <username> [duration]";
  }
  else {
    my $victimname = shift(@chatarray);
    my $victim = $victimname ? $DCBUser::userlist->{lc($victimname)} : '';
    my $gagtime = @chatarray ? shift(@chatarray) : DCBSettings::config_get('gag_default_time');
    my $reason = @chatarray ? join(' ', @chatarray) : DCBSettings::config_get('gag_default_message');

    if ($victim && $victim->{uid}) {
      if ($user->{permission} >= $victim->{permission}) {
        $botmessage = "$user->{name} has gagged $victimname for $gagtime seconds: $reason";

        @return = (
          {
            param   => "message",
            message => $botmessage,
            user    => $victim->{name},
            touser  => '',
            type    => MESSAGE->{'PUBLIC_ALL'},
          },
          {
            param   => "message",
            message => "You have been gagged by $user->{name}: $reason",
            user    => $victim->{name},
            touser  => '',
            type    => MESSAGE->{'BOT_PM'},
          },
          {
            param  => "action",
            user   => $victim->{name},
            action => 'gag',
            arg    => $gagtime,
          },
          {
            param  => "log",
            action => "gag",
            arg    => $botmessage,
            user   => $user,
          },
        );
        return @return;
      }
      else {
        $botmessage = DCBSettings::config_get('no_perms');
      }
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
