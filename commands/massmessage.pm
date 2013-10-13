package massmessage;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();

  # No need to check permissions here, specified in YAML file
  my $message = "Mass message from " . $user->{name} . ": " . $chat;

  @return = (
    {
      param => "message",
      message => $message,
      type => 5,
      user => '',
      touser => '',
    }
  );

  return @return;
}

1;
