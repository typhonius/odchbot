package rules;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;

sub schema {
  my %schema = (
    config => {
      web_rules => '/rules',
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;

  my $website = DCBSettings::config_get('website');
  my $hubname = DCBSettings::config_get('hubname');
  my $rules = DCBSettings::config_get('web_rules');
  my $message = 'Link to current ' . $hubname . ' rules: ' . $website . $rules;

  my @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_SINGLE'},
    },
  );
  return @return;
}

1;
