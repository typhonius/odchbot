package load;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBUser;
use DCBCommon;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();
  my $message = "Available Commands: \n";

  # Check the YAML file at least exists and that the command is not already loaded.
  if ($DCBCommon::registry->{commands}->{$chat}) {
    $message = "$chat command already loaded.";
  }
  else {
    my $path = ($DCBSettings::cwd . $DCBSettings::config->{commandPath} . "/" . $chat. ".yml");

    if (open my $fh, '+<', $path) {
      close $fh;
      my @file = glob($DCBSettings::cwd . $DCBSettings::config->{commandPath} . "/" . $chat. ".yml");
      DCBCommon::commands_load_commands(@file);
      $message = "$chat command loaded."
    }
    else {
      $message = 'YAML file not found.';
    }
  }
  #commands_load_commands(@files);


  @return = (
    {
      param    => "message",
      message  => $message,
      user     => '',
      touser   => '',
      type     => MESSAGE->{'PUBLIC_ALL'},
    },
    {
      param    => "log",
      action   => "load",
      arg      => $message,
      user     => $user->{name},
    },
  );
  return @return;
}

1;
