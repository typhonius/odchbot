package uptime;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;

my $boot_time;

sub init {
  my $command = shift;
  $boot_time = time();
  return;
}

sub main {
  my $command = shift;
  my $user = shift;

  my $uptime_seconds = time() - $boot_time;
  my $days = int($uptime_seconds / 86400);
  my $hours = int(($uptime_seconds % 86400) / 3600);
  my $mins = int(($uptime_seconds % 3600) / 60);
  my $secs = $uptime_seconds % 60;

  my $botname = DCBSettings::config_get('botname');
  my $version = DCBSettings::config_get('version');
  my $started = DCBCommon::common_timestamp_time($boot_time);

  my $message = "$botname $version uptime: ${days}d ${hours}h ${mins}m ${secs}s (since $started)";

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
