package magic_8ball;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBDatabase;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $params = shift;

  my @return = ();

  my @choices = ("Yes, in due time.", "My sources say no.", "Definitely not.", "Outlook so so.", "Who knows?", "I have my doubts.", "Probably.", "Are you kidding?", "Don't bet on it.", "Looks good to me.");
  @return = (
    {
      param    => "message",
      message  => $choices[int(rand(@choices))],
      user     => $user->{name},
      touser   => '',
      type     => 4,
    },
    {
      param    => "message",
      message  => "Private message",
      user     => "mark",
      touser   => $user->{name},
      type     => 9,
    },
  );
  return @return;
}

sub postlogin {
  my $command = shift;
  my $user = shift;
  my @return = (
    {
      param    => "message",
      message  => "postlogin 8ball hi there $user->{name}",
      user     => '',
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

1;