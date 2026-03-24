package uptime;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;

sub init {
  $DCBCommon::COMMON->{uptime} = {
    start_time => time(),
  };
}

sub main {
  my $command = shift;
  my $user = shift;
  my @return = ();

  my $start = $DCBCommon::COMMON->{uptime}->{start_time} || time();
  my $duration = DCBCommon::common_timestamp_duration($start);
  my $started = DCBCommon::common_timestamp_time($start);

  my $message = "Bot uptime: $duration\nStarted: $started";

  @return = ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
  return @return;
}

1;
