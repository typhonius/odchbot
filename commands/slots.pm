package slots;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;

sub main {
  my $command = shift;
  my $user = shift;
  my @return = ();

  my @symbols = ('<7>', '<$>', '<*>', '<#>', '<%>', '<@>', '<+>');
  my @weights = ( 5,     10,    15,    20,    20,    20,    10  );

  # Weighted random selection
  my @reel1 = slots_spin(\@symbols, \@weights);
  my @reel2 = slots_spin(\@symbols, \@weights);
  my @reel3 = slots_spin(\@symbols, \@weights);

  my $s1 = $reel1[0];
  my $s2 = $reel2[0];
  my $s3 = $reel3[0];

  my $result = "[ $s1 | $s2 | $s3 ]";
  my $message = "$user->{name} pulls the lever...\n$result\n";

  # Check results
  if ($s1 eq $s2 && $s2 eq $s3) {
    if ($s1 eq '<7>') {
      $message .= "*** JACKPOT!!! Triple 7s! You are incredibly lucky! ***";
      eval {
        if ($DCBCommon::COMMON->{ranks}) {
          push(@return, ranks::ranks_add_xp($user, 100, 'social_xp'));
        }
      };
    }
    elsif ($s1 eq '<$>') {
      $message .= "*** BIG WIN! Triple dollars! ***";
      eval {
        if ($DCBCommon::COMMON->{ranks}) {
          push(@return, ranks::ranks_add_xp($user, 30, 'social_xp'));
        }
      };
    }
    else {
      $message .= "*** THREE OF A KIND! Nice spin! ***";
      eval {
        if ($DCBCommon::COMMON->{ranks}) {
          push(@return, ranks::ranks_add_xp($user, 15, 'social_xp'));
        }
      };
    }
  }
  elsif ($s1 eq $s2 || $s2 eq $s3 || $s1 eq $s3) {
    $message .= "Two of a kind! Not bad.";
    eval {
      if ($DCBCommon::COMMON->{ranks}) {
        push(@return, ranks::ranks_add_xp($user, 3, 'social_xp'));
      }
    };
  }
  else {
    $message .= "No match. Better luck next time!";
  }

  push(@return, {
    param   => "message",
    message => $message,
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub slots_spin {
  my ($symbols, $weights) = @_;
  my $total = 0;
  $total += $_ for @{$weights};
  my $roll = int(rand($total));
  my $cumulative = 0;
  for (my $i = 0; $i < scalar @{$symbols}; $i++) {
    $cumulative += $weights->[$i];
    if ($roll < $cumulative) {
      return ($symbols->[$i]);
    }
  }
  return ($symbols->[0]);
}

1;
