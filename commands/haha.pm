package haha;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;

sub main {
  my $command = shift;
  my $user = shift;
  my $range = 6;
  my $random_number = int(rand($range));
  my $message = "message";
  my $website = DCBSettings::config_get('website');
  my @return = ();

  if ($random_number == 0) {
    $message = $user->{name} . " has been kicked because they rolled a " . $random_number;
    @return = (
     {
        param    => "message",
        message  => $message,
        user     => $user->{name},
        touser   => '',
        type     => MESSAGE->{'PUBLIC_ALL'},
      },
      {
        param    => "action",
        user     => $user->{name},
        action   => 'kick',
      },
    );
  } else {
    $message = $user->{name} . " has not been kicked because they rolled a " . $random_number . ". CN: " . $website;
    @return = (
     {
        param    => "message",
        message  => $message,
        user     => $user->{name},
        touser   => '',
        type     => MESSAGE->{'PUBLIC_ALL'},
      },
    );
  }
  return @return;
}

1;
