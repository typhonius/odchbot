package ODCHBot::Formatter;
use strict;
use warnings;
use Exporter qw(import);
use DateTime;
use DateTime::Duration;
use DateTime::Format::Duration;
use Number::Bytes::Human qw(format_bytes);
use POSIX qw(floor);

our @EXPORT_OK = qw(
    format_timestamp
    format_duration
    format_size
    escape_string
    format_duration_short
);

my $duration_fmt = DateTime::Format::Duration->new(
    pattern   => '%Y years, %m months, %e days, %H hours, %M minutes, %S seconds',
    normalize => 1,
);

sub format_timestamp {
    my ($epoch, $timezone) = @_;
    $timezone //= 'UTC';
    my $dt = DateTime->from_epoch(epoch => $epoch, time_zone => $timezone);
    return $dt->strftime('%Y-%m-%d %H:%M:%S %Z');
}

sub format_duration {
    my ($seconds) = @_;
    return '0 seconds' unless $seconds && $seconds > 0;

    my $now  = DateTime->now;
    my $then = DateTime->from_epoch(epoch => time() - $seconds);
    my $dur  = $now - $then;

    my $str = $duration_fmt->format_duration($dur);
    # Strip leading zero components
    $str =~ s/^(?:0 \w+,\s*)+//;
    $str =~ s/,\s*$//;
    return $str || '0 seconds';
}

sub format_duration_short {
    my ($seconds) = @_;
    return '0s' unless $seconds && $seconds > 0;

    my $days  = floor($seconds / 86400);
    my $hours = floor(($seconds % 86400) / 3600);
    my $mins  = floor(($seconds % 3600) / 60);
    my $secs  = $seconds % 60;

    my @parts;
    push @parts, "${days}d"  if $days;
    push @parts, "${hours}h" if $hours;
    push @parts, "${mins}m"  if $mins;
    push @parts, "${secs}s"  if $secs || !@parts;
    return join(' ', @parts);
}

sub format_size {
    my ($bytes) = @_;
    return format_bytes($bytes // 0);
}

sub escape_string {
    my ($str) = @_;
    return '' unless defined $str;
    $str =~ s/\$/\&#36;/g;
    $str =~ s/\|/\&#124;/g;
    return $str;
}

1;
