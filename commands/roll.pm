package roll;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my $num_dice = 1;
  my $num_sides = 6;
  my $message = '';

  if ($chat && $chat =~ /^(\d+)d(\d+)$/i) {
    $num_dice = $1;
    $num_sides = $2;
  }
  elsif ($chat && $chat =~ /^d(\d+)$/i) {
    $num_sides = $1;
  }
  elsif ($chat && $chat =~ /^(\d+)$/i) {
    $num_sides = $1;
  }

  # Sanity limits
  if ($num_dice < 1 || $num_dice > 100) {
    $message = "Number of dice must be between 1 and 100";
  }
  elsif ($num_sides < 2 || $num_sides > 1000) {
    $message = "Number of sides must be between 2 and 1000";
  }
  else {
    my @rolls = ();
    my $total = 0;
    for (1 .. $num_dice) {
      my $r = int(rand($num_sides)) + 1;
      push @rolls, $r;
      $total += $r;
    }

    if ($num_dice == 1) {
      $message = "$user->{name} rolled a d$num_sides: $total";
    }
    else {
      my $roll_str = join(', ', @rolls);
      $message = "$user->{name} rolled ${num_dice}d${num_sides}: $total [$roll_str]";
    }
  }

  my @return = (
    {
      param   => "message",
      message => $message,
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

1;
