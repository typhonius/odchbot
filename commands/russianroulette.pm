package russianroulette;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;

sub schema {
  my %schema = (
    config => {
      russianroulette_barrel => 6,
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;

  my @return = ();
  my $message = "";
  my $num_barrels = 6;

  my $barrel = DCBSettings::config_get('russianroulette_barrel');

  if ($barrel == 0) {
    $message = "BANG\!";
    # Load a bullet and spin to a random barrel
    $barrel = int(rand($num_barrels));
    @return = (
      {
        param => "message",
        message => $message,
        user => '',
        touser => '',
        type => MESSAGE->{'PUBLIC_ALL'},
      },
      {
        param => "action",
        action => "kick",
        arg => $message,
        user => $user->{name},
      },
    );
  } else {
    $message = "Click\!";
    $barrel--;
    @return = (
      {
        param => "message",
        message => $message,
        user => '',
        touser => '',
        type => MESSAGE->{'PUBLIC_ALL'},
      },
    );
  }

  # Update current cocked barrel
  DCBSettings::config_set('russianroulette_barrel', $barrel);

  return @return;
}

1;
