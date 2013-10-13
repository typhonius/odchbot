package unload;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my $message = '';
  my @return = ();

  if ($DCBCommon::registry->{commands}->{$chat}) {
    my $to_unload = $DCBCommon::registry->{commands}->{$chat};
    if (!$to_unload->{required}) {
      if (DCBCommon::commands_unload_commands($to_unload)) {
        $message = "$chat command has been unloaded.";
      }
      else {
        $message = "Failure: Unable to unload command.";
      }
    }
    else {
      $message = "$chat is required: Unable to be unloaded.";
    }
  }
  else {
    $message = "$chat does not exist: Unable to be unloaded.";
  }

  @return = (
    {
      param    => "message",
      message  => "$message",
      user     => $user->{name},
      touser   => '',
      type     => 4,
    },
    {
      param    => "log",
      action   => "unload",
      arg      => $message,
      user     => $user,
    },
  );
  return @return;
}

1;
