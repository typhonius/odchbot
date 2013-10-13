package lasercats;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";

sub main {
  my $command = shift;
  my $user = shift;
  my @return = ();

  my @lasercats = ('PEW PEW PEW', 'FUUUUUUUUUUUUCKIIIIIIIIING LAAAAAAAAASERCAAAAAAAAAAAAAAAATS!');
  foreach my $message (@lasercats) {
    my @messages = (
      {
        param    => "message",
        message  => "$message",
        user     => $user->{name},
        touser   => '',
        type     => 4,
      }
    );
    push(@return, @messages);
  }
  my @kick = (
    {
      param    => "action",
      user     => $user->{name},
      action   => 'kick',
    },
  );
  push(@return, @kick);

  return @return;
}

1;
