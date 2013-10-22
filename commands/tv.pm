package tv;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;

sub main {
  my $command = shift;
  my $user = shift;

  my @return = ();

  @return = (
    {
      param    => "message",
      message  => "This will return the TV command",
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

1;
