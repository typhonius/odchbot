package search;

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
      message  => "Placeholder for search command",
      user     => $user->{name},
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

1;
