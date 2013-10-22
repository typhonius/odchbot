package DCBCommon;

use strict;
use warnings;
use DCBSettings;
use DCBDatabase;
use DateTime;
use DateTime::Duration;
use DateTime::Format::Duration;
use Number::Bytes::Human;
use YAML::AppConfig;
use Storable qw(freeze thaw dclone);
use Module::Load;
use Exporter;
our @ISA= qw(Exporter);
our @EXPORT = qw(registry_rebuild commands_run_command registry_add common_timestamp_time common_timestamp_duration common_format_size MESSAGE);
use FindBin;
use lib "$FindBin::Bin";

# For further information about these constants read the README.
use constant MESSAGE => {
  HUB_PUBLIC      => 1,
  PUBLIC_SINGLE   => 2,
  BOT_PM          => 3,
  PUBLIC_ALL      => 4,
  MASS_MESSAGE    => 5,
  SPOOF_PM_BOTH   => 6,
  SEND_TO_OPS     => 7,
  HUB_PM          => 8,
  SPOOF_PM_SINGLE => 9,
  SPOOF_PUBLIC    => 10,
  RAW             => 11,
  SEND_TO_ADMINS  => 12,
};

sub new { return bless {}, shift }

sub common_init {
  # Instantiate a shared variable for other commands to use.
  our $COMMON = ();
}

sub commands_init {
  use FindBin;
  push (@INC, "$FindBin::Bin/$DCBSettings::config->{commandPath}");
  registry_init();
  return;
}

sub registry_init {
  our $registry = ();
  my $registryh = DCBDatabase::db_select('registry');
  while (my $command = $registryh->fetchrow_hashref()) {
    registry_add($command);
  }
  # If the bot has never been initialised the registry won't have anything
  # so we need to parse all the commands and fill the registry.
  if (!$registry) {
    registry_rebuild();
  }
  return;
}

sub registry_add {
  my $command = shift;
  $DCBCommon::registry->{commands}->{$command->{name}} = $command;
  if ($command->{alias}) {
    my $aliases = thaw($command->{alias});
    foreach (@$$aliases) {
      $DCBCommon::registry->{commands}->{$_} = dclone($command);
    }
  }
  if ($command->{hooks}) {
    my $hooks = thaw($command->{hooks});
    foreach (@$$hooks) {
      $DCBCommon::registry->{hooks}->{$_}->{$command->{name}} = $command->{name};
    }
  }
}

sub registry_remove {
  my $command = shift;
  delete($DCBCommon::registry->{commands}->{$command->{name}});
  if ($command->{alias}) {
    my $aliases = thaw($command->{alias});
    foreach (@$$aliases) {
      delete($DCBCommon::registry->{commands}->{$_});
    }
  }
  if ($command->{hooks}) {
    my $hooks = thaw($command->{hooks});
    foreach (@$$hooks) {
      delete($DCBCommon::registry->{hooks}->{$_}->{$command->{name}});
    }
  }
}

# This sub can also be called to completely wipe and rebuild the registry.
sub registry_rebuild {
  my $command = shift;
  $command ||= '*';
  my %where = ();

  if ($command !~ /^\*$/) {
    %where = (
      name => $command,
    );
  }
  DCBDatabase::db_delete('registry', \%where);

  my @files = ();
  @files = glob($DCBSettings::cwd . $DCBSettings::config->{commandPath} . "/" . $command. ".yml");
  commands_load_commands(@files);
  return;
}

sub commands_install_command {
  my $command = shift;
  my $schema = commands_run_command($command, 'schema');
  # TODO config_set support
  if ($schema->{schema}) {
    DCBDatabase::db_create_table($schema);
  }
  if ($schema->{config}) {
    foreach my $key (keys %{$schema->{config}}) {
      DCBSettings::config_set($key, $schema->{config}->{$key});
    }
  }
}

sub commands_uninstall_command {
  my $command = shift;
  # Ensure the command isn't a required command
  my $schema = commands_run_command($command, 'schema');
  if ($schema->{schema}) {
    DCBDatabase::db_drop_table($schema);
  }
  if ($schema->{config}) {
    foreach my $key (keys %{$schema->{config}}) {
      DCBSettings::config_delete($key, $schema->{config}->{$key});
    }
  }
  return 1;
}

sub commands_load_commands {
  my @files = @_;
  my $yaml = '';
  foreach (@files) {
    # eval in case the yaml file is malformed.
    eval {
      $yaml = YAML::AppConfig->new(file => $_);
    };
    if (!$@) {
      # Loaded the YAML file ok so process it.
      my %fields = (
        'name' => $yaml->{config}->{name},
        'description' => $yaml->{config}->{description},
        'required' => $yaml->{config}->{required},
        'path' => $_,
        'status' => 1,
        'system' => $yaml->{config}->{system},
        'permissions' => DCBUser::user_permissions(@{ $yaml->{config}->{permissions} }),
        'alias' => $yaml->{config}->{alias} ? freeze( \$yaml->{config}->{alias} ) : '',
        'hooks' => $yaml->{config}->{hooks} ? freeze( \$yaml->{config}->{hooks} ) : '',
      );
      DCBDatabase::db_insert('registry', \%fields);
      registry_add(\%fields);
      commands_install_command(\%fields);
    }
  }
  return;
}

sub commands_unload_commands {
  my $command = shift;
  unless ($command->{required}) {
    my %where = (name => $command->{name});
    # TODO transaction here?
    commands_uninstall_command($command);
    DCBDatabase::db_delete('registry', \%where);
    registry_remove($command);
    return 1;
  }
  return 0;
}

sub commands_run_command {
  my $command = shift;
  my $hook = shift;
  $hook ||= 'main';
  my $user = shift;
  my $params = shift;
  my $commandname = $command->{name};

  if ($command->{status}) {
    # if it's already loaded, don't load it.
    if (!$INC{$commandname . '.pm'}) {
      load $commandname;
    }
    if ($commandname->can($hook)) {
      return $commandname->$hook($user, $params);
    }
  }
  return;
}

sub common_escape_string {
  my $string = shift;
  $string =~ s/$_/$_/ for qw(\\\ \| \\( \\) \[ \{ \$ \+ \? \. \* \/ \^);
  return $string;
}

sub common_timestamp_time {
  my $time = shift;
  my $date = DateTime->from_epoch( epoch => $time );
  $date->set_time_zone($DCBSettings::config->{timezone});
  return $date->strftime("%Y-%m-%d %H:%M:%S");
}

sub common_timestamp_duration {
  my $epoch = shift;
  my $dt = DateTime->from_epoch( epoch => $epoch );
  my $now = DateTime->now();
  my $dur = $now->subtract_datetime($dt);
  my $format = DateTime::Format::Duration->new(
    pattern => '%Y years, %m months, %e days, %l hours, %M minutes, %S seconds'
  );
  $format->set_normalising('true');
  return $format->format_duration($dur);
}

sub common_format_size {
  my $bytes = shift;
  my $h = Number::Bytes::Human->new(bs => 1024, si => 1, round_style => 'floor');
  return $h->format($bytes);
}

1;
