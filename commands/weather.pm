package weather;

use utf8;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;

use LWP::Simple;
use XML::Simple;

sub schema {
  my %schema = (
    config => {
      weather_cache_time => 3600,
      weather_last_called => 0,
      weather_feed => 'http://rss.weather.com.au/act/canberra',
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $message = "Weather:\n";

  if (!$DCBCommon::COMMON->{'weather'} || time() - DCBSettings::config_get('weather_last_called') > DCBSettings::config_get('weather_cache_time')) {
    my $weather_feed = DCBSettings::config_get('weather_feed');
    my $content = get($weather_feed);
    my $data = XMLin($content);

    my $c = $data->{channel}->{item}->[0]->{'w:current'};
    my $f = $data->{channel}->{item}->[1]->{'w:forecast'};

    my $current = <<EOF;
      Temperature:  $c->{temperature} °C
      Dew Point:      $c->{dewPoint} °C
      Rel. Humidity:  $c->{humidity} \%
      Wind:           $c->{windSpeed} km/h $c->{windDirection}, gusting to $c->{windGusts} km/h
      Air Pressure:   $c->{pressure} hPa
      Rain since 9am: $c->{rain} mm
EOF

    $message .= "Current conditions:\n" . $current;

    $message .= "\n3-day forecast:\n";
    foreach my $day (@{$f}) {
      $message .= <<EOF;
      $day->{day}:
        Temperatures: $day->{min}–$day->{max} °C
        Conditions:   $day->{description}
EOF
    }
    $DCBCommon::COMMON->{'weather'} = $message;
    DCBSettings::config_set('weather_last_called', time());
  }
  else {
    $message = $DCBCommon::COMMON->{'weather'};
  }

  my @return = (
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

1;

