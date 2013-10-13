#Written by Wickfish May 2013 for Chaotic Neutral
package karma;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";

sub schema {
  my %schema = (
    config => {
      web_karma => '/karma',
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;

  my $website = DCBSettings::config_get('website');
  my $hubname = DCBSettings::config_get('hubname');
  my $karma = DCBSettings::config_get('web_karma');
  my $message = 'Link to current ' . $hubname . ' karma: ' . $website . $karma;

  my @return = ();
  @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => 2,
    },
  );
  return @return;
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  if ($chat =~ /(\S+)(\+\+)(\s.*)?$/ || $chat =~ /(\w+)(--)(\s.*)?$/) {
    @return = (
      {
        param    => "message",
        message  => "$2 karma assigned to $1",
        user     => $user->{name},
        fromuser => '',
        type     => 2,
      },
    );
  }

  return @return;
}

1;
