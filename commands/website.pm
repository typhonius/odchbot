package website;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;

sub main {
  my $command = shift;
  my $user = shift;
  
  my @return = ();
  
  my $hub_name = DCBSettings::config_get('hubname');
  my $hub_href = DCBSettings::config_get('website');
  my $message = "Link to " . $hub_name . " website: " . $hub_href;
  
  @return = (
    {
      param => "message",
      message => $message,
      type => 2,
      user => $user->{name},
      touser => '',
    },
  );
  
  return @return;
}

1;
