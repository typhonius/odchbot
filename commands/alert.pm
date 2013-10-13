package alert;

use strict;
use warnings;
use POSIX;
use Scalar::Util qw(looks_like_number);
use FindBin;
use lib "$FindBin::Bin/..";

sub schema {
  my %schema = (
    config => {
      alert_message => "",
      alert_time_spacing => 60,
      alert_last_sent => 0,
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @chatarray = split(/\s+/, $chat);
  my $alert_time = shift(@chatarray);
  my $alert_message = join(' ', @chatarray);
  my $message = '';

  if ($alert_time =~ /off/) {
    DCBSettings::config_set('alert_message', '');
    $message = "Alerts off";
  }
  else {
    # Snip the h or m off the time and convert everything to minutes. Since HUB_TIMER fires every 15 mins, round.
    my $minutes = (($alert_time =~ /\d+h/) ? (substr($alert_time, 0, -1) * 60) : substr($alert_time, 0, -1));
    $message = "Text should be in the format -alert <time>m/h <message>";

    if (looks_like_number($minutes) && $alert_message) {
      $message = "'$alert_message' set to display every $minutes minutes.";
      DCBSettings::config_set('alert_time_spacing', int(ceil($minutes / 15)) * 15);
      DCBSettings::config_set('alert_message', $alert_message);
    }
  }

  my @return = (
    {
      param    => "message",
      message  => "$message",
      user     => $user->{name},
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

sub timer {
  my @return = ();
  if ($DCBSettings::config->{alert_last_sent} + ($DCBSettings::config->{alert_time_spacing} * 60) <= time()) {
    @return = (
      {
        param    => "message",
        message  => $DCBSettings::config->{alert_message},
        user     => '',
        touser   => '',
        type     => 4,
      },
    );
    DCBSettings::config_set('alert_last_sent', time());
  }

  return @return;
}

1;
