#Written by Wickfish May 2013 for Chaotic Neutral
package kick;
  use strict;
  use warnings;
  use FindBin;
  use lib "$FindBin::Bin/..";
  use DCBSettings;
  use DCBUser;
  
sub main {
  my $command = shift;
  my $user = shift;
  my @chatarray = split(/\s+/, shift);
  my $victim = @chatarray ? $DCBUser::userlist->{lc(shift(@chatarray))} : '';
  my $kickmessage = @chatarray ? join(' ', @chatarray) : DCBSettings::config_get('default_kick');
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
          type     => 8,
        },
        {
          param    => "message",
          message  => $botmessage,
          user     => $victim->{name},
          touser   => '',
          type     => 4,
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
      type     => 4,
    },
	);
 
  return @return;
}

1;
