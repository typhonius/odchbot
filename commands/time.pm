package time;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use Scalar::Util qw(looks_like_number);
use DCBCommon;
use DCBSettings;

sub main {
  my $command = shift;
  my $user = shift;
  my $time = shift;

  my $message = '';
  my $timezone = DCBSettings::config_get('timezone');
  if (looks_like_number($time)) {
    $message .= $timezone . ': ' . DCBCommon::common_timestamp_time($time);
  }
  else {
    $message .= $timezone . ': ' . DCBCommon::common_timestamp_time(time());
  }

  my @return = ();

  @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

1;
