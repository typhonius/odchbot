package coin;

use strict;
use warnings;
use Switch;
use FindBin;
use lib "$FindBin::Bin/..";

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();
  my @yesno = ('yes', 'no');
  my @coin = ('Heads', 'Tails');
  my $rand = int(rand(2));
  my $message = '';

  if (length($chat)) {
    if ($chat =~ /\sor\s/) {
      my @decide = split(/\sor\s/, $chat);
      my $rnd = int(rand(@decide));
      $message = "The answer to '" . $chat . "' is " . $decide[$rnd];
    }
    else {
      $message = "The answer to '" . $chat . "' is " . $yesno[$rand];
    }
  }
  else {
    $message = $coin[$rand];
  }

  @return = (
    {
      param    => "message",
      message  => $message,
      user     => '',
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

1;
