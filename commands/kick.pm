package kick;

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
      kick_default => "Halt bro! You have been kicked http://i.imgur.com/QPt5n.jpg",
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my @chatarray = split(/\s+/, shift);
  my $victim = @chatarray ? $DCBUser::userlist->{lc(shift(@chatarray))} : '';
  my $kickmessage = @chatarray ? join(' ', @chatarray) : DCBSettings::config_get('kick_default');
  my $botmessage = "$user->{'name'} is kicking $victim->{'name'} because $kickmessage";
  my @return = ();

  # Check that the victim is actually a user who is online
  if ($victim && ($victim->{'connect_time'} > $victim->{'disconnect_time'})) {
    # If the user is lower permission than the victim, make the kick fail
    if ($user->{'permission'} >= $victim->{'permission'}) {
      @return = (
        {
          param    => "message",
          message  => $kickmessage,
          user     => $victim->{name},
          touser   => '',
          type     => MESSAGE->{'HUB_PM'},
        },
        {
          param    => "message",
          message  => $botmessage,
          user     => $victim->{name},
          touser   => '',
          type     => MESSAGE->{'PUBLIC_ALL'},
        },
        {
          param    => "action",
          user     => $victim->{name},
          action   => 'kick',
        },
        {
          param    => "log",
          action   => "kick",
          arg  => $botmessage,
          user     => $user,
        },
      );
      return(@return);
    }
    else {
      $botmessage = DCBSettings::config_get('no_perms');
    }
  }
  else {
    $botmessage = "User does not exist or is offline";
  }
 
  @return = (
    {
      param    => "message",
      message  => $botmessage,
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_ALL'},
    },
  );
 
  return @return;
}

1;
