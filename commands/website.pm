package website;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;

sub schema {
  my %schema = (
    config => {
      website => 'http://example.com',
    },
  );
  return \%schema;
}

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
      type => MESSAGE->{'PUBLIC_SINGLE'},
      user => $user->{name},
      touser => '',
    },
  );
  
  return @return;
}

1;
