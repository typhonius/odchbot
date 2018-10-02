package DCBSettings;

use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use YAML::AppConfig;

my $config_file = 'odchbot.yml';

sub new { return bless {}, shift }

sub config_init() {
  my ($class, $config_name) = @_;

  my $yaml = config_load();
  our $config = $yaml->get('config');
}

sub config_load() {
  our ( $settings, $cwd, $suffix ) = fileparse( abs_path(__FILE__) );

  # Create a new YAML object and get the config settings from file
  # Nested variables may be used: $config->{variables}->{timezone}
  return YAML::AppConfig->new( file => $cwd . $config_file );
}

sub config_set {
  my $variable = shift;
  my $value = shift;
  my $yaml = config_load();
  $DCBSettings::config->{$variable} = $value;
  $yaml->{config}->{config}->{$variable} = $value;
  return config_save($yaml);
}

sub config_get {
  my $variable = shift;
  if ($DCBSettings::config->{$variable}) {
    return $DCBSettings::config->{$variable};
  }
  return 0;
}

sub config_delete {
  my $variable = shift;
  my $yaml = config_load();
  if ($DCBSettings::config->{$variable}) {
    delete($DCBSettings::config->{$variable});
    delete($yaml->{config}->{config}->{$variable});
    return config_save($yaml);
  }
  return 0;
}

sub config_reload {
  my $yaml = config_load();
  my $conf = $yaml->get('config');
  foreach my $key (keys %{$conf}) {
    # Definitely do not override the db.
    if ($key ne 'db' && $key ne 'jabber') {
      if (!exists($DCBSettings::config->{$key}) || $DCBSettings::config->{$key} ne $conf->{$key}) {
        $DCBSettings::config->{$key} = $conf->{$key};
      }
    }
  }
  return 1;
}

sub config_save {
  my $yaml = shift;
  if ($yaml->dump($DCBSettings::cwd . $config_file)) {
    return 1;
  }
  return 0;
}

1;
