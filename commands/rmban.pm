package rmban;

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
  my @chatarray = split(/\s+/, shift);
  my $victim = @chatarray ? $DCBUser::userlist->{lc(shift(@chatarray))} : '';
  my $botmessage = '';
  my @return = ();

  # Check that the victim is actually a user
  if ($victim) {
    $botmessage = "$user->{'name'} is unbanning $victim->{'name'}";

    @return = (
      {
        param    => "message",
        message  => $botmessage,
        user     => $victim->{name},
        touser   => '',
        type     => MESSAGE->{'PUBLIC_ALL'},
      },
      {
        param    => "log",
        action   => "ban",
        arg      => $botmessage,
        user     => $user,
      },
    );
    if (DCBSettings::config_get('ban_handler') =~ 'bot') {
      # We handle the unban in the bot rather than allow ODCH to handle
      my %where = ('uid' => $victim->{'uid'});
      DCBDatabase::db_delete('ban', \%where)
    }
    else {
      my @unnickban = (
        {
          param    => "action",
          user     => $victim->{name},
          action   => 'unnickban',
        },
      );
      push(@return, @unnickban);
    }
    return(@return);
    
  }
  else {
    $botmessage = "User does not exist.";
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
