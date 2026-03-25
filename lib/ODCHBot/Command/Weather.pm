package ODCHBot::Command::Weather;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

my $_weather_cache = '';

sub meta_info {{
    name        => 'weather',
    description => 'Display current weather and forecast',
    usage       => 'weather',
    permission  => ODCHBot::User::PERM_ANONYMOUS,
    hooks       => ['timer'],
}}

sub execute {
    my ($self, $ctx) = @_;
    my $cache_time = $self->config->get('weather_cache_time') // 3600;
    my $last_called = $self->config->get('weather_last_called') // 0;

    my $message;
    if (!$_weather_cache || (time() - $last_called) > $cache_time) {
        $message = $self->_fetch_weather;
    }
    else {
        $message = $_weather_cache;
    }

    $ctx->reply($message // 'Unable to fetch weather data.');
}

sub on_timer {
    my ($self, $data) = @_;
    my $cache_time = $self->config->get('weather_cache_time') // 3600;
    my $last_called = $self->config->get('weather_last_called') // 0;

    if (!$_weather_cache || (time() - $last_called) > $cache_time) {
        $self->_fetch_weather;
    }
    return;
}

sub _fetch_weather {
    my ($self) = @_;
    my $feed = $self->config->get('weather_feed') // return 'Weather feed not configured.';

    require LWP::Simple;
    require XML::Simple;

    my $content = LWP::Simple::get($feed);
    return 'Unable to fetch weather feed.' unless $content;

    my $data = eval { XML::Simple::XMLin($content) };
    return 'Unable to parse weather data.' if $@ || !$data;

    my $c = $data->{channel}{item}[0]{'w:current'} // {};
    my $forecasts = $data->{channel}{item}[1]{'w:forecast'};

    my $message = "Weather:\nCurrent conditions:\n";
    $message .= "  Temperature:  " . ($c->{temperature} // '?') . " C\n";
    $message .= "  Dew Point:    " . ($c->{dewPoint}    // '?') . " C\n";
    $message .= "  Humidity:     " . ($c->{humidity}     // '?') . " %\n";
    $message .= "  Wind:         " . ($c->{windSpeed} // '?') . " km/h " . ($c->{windDirection} // '') . ", gusting to " . ($c->{windGusts} // '?') . " km/h\n";
    $message .= "  Air Pressure: " . ($c->{pressure}    // '?') . " hPa\n";
    $message .= "  Rain since 9am: " . ($c->{rain}      // '?') . " mm\n";

    if ($forecasts && ref $forecasts eq 'ARRAY') {
        $message .= "\n3-day forecast:\n";
        for my $day (@$forecasts) {
            $message .= "  " . ($day->{day} // '?') . ":\n";
            $message .= "    Temperatures: " . ($day->{min} // '?') . "-" . ($day->{max} // '?') . " C\n";
            $message .= "    Conditions:   " . ($day->{description} // '?') . "\n";
        }
    }

    $_weather_cache = $message;
    $self->config->set('weather_last_called', time());
    return $message;
}

1;
