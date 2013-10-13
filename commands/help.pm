package help;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";

sub main {
  my $command = shift;
  my $user = shift;

  my @return = ();

  @return = (
    {
      param    => "message",
      message  => "Placeholder for help command",
      user     => '',
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

1;
