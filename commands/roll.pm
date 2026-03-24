package roll;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  $chat =~ s/^\s+|\s+$//g;

  # Default: 1d6
  if (!$chat || $chat eq '') {
    $chat = '1d6';
  }

  my $message = '';

  # Parse dice notation: NdS+M (e.g., 2d6, 3d8+5, d20, 4d6-2)
  if ($chat =~ /^(\d*)d(\d+)([+-]\d+)?$/i) {
    my $num = $1 || 1;
    my $sides = $2;
    my $modifier = $3 || 0;

    # Sanity limits
    if ($num > 100) {
      $message = "Maximum 100 dice at once!";
    }
    elsif ($sides > 1000) {
      $message = "Maximum 1000 sides per die!";
    }
    elsif ($sides < 1) {
      $message = "Dice need at least 1 side!";
    }
    else {
      my @rolls = ();
      my $total = 0;
      for (my $i = 0; $i < $num; $i++) {
        my $roll = int(rand($sides)) + 1;
        push(@rolls, $roll);
        $total += $roll;
      }

      $total += $modifier;
      my $roll_str = join(', ', @rolls);
      my $mod_str = $modifier > 0 ? "+$modifier" : $modifier < 0 ? "$modifier" : '';

      if ($num == 1) {
        $message = "$user->{name} rolled a d$sides$mod_str: $total";
      }
      else {
        $message = "$user->{name} rolled ${num}d$sides$mod_str: [$roll_str] = $total";
      }
    }
  }
  # Simple number: roll 1-N
  elsif ($chat =~ /^(\d+)$/) {
    my $max = $1;
    if ($max < 1) { $max = 6; }
    if ($max > 1000000) { $max = 1000000; }
    my $roll = int(rand($max)) + 1;
    $message = "$user->{name} rolled 1-$max: $roll";
  }
  else {
    $message = "Usage: -roll [NdS+M] (e.g., -roll 2d6, -roll d20, -roll 3d8+5, -roll 100)";
  }

  @return = ({
    param   => "message",
    message => $message,
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
  return @return;
}

1;
