package commands;

use strict;
use warnings;
use Storable qw(thaw);
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;
use DCBSettings;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my @chatarray = split(/\s+/, shift);
  my $specific = @chatarray ? shift(@chatarray) : '';
  my @return = ();

  my $message = "\n";

  if ($specific && $DCBCommon::registry->{commands}->{$specific} && (user_access($user, $DCBCommon::registry->{commands}->{$specific}->{permissions}))) {
    my $command = $DCBCommon::registry->{commands}->{$specific};
    $message .= DCBCommon::common_escape_string("$DCBSettings::config->{cp}") . "$command->{name}: $command->{description}";
    if ($command->{alias}) {
      $message .= "\nAliases: ";
      my $aliases = thaw($command->{alias});
      foreach (@$$aliases) {
        $message .= "$_ ";
      }
    }
    if ($command->{hooks}) {
      $message .= "\nHooks: ";
      my $hooks = thaw($command->{hooks});
      foreach (@$$hooks) {
        $message .= "$_ ";
      }
    }
    $message .= "\nRequired: " . $command->{required};
    $message .= "\nStatus: " . $command->{status};
  }
  else {
    foreach my $commands (sort keys %{$DCBCommon::registry->{commands}}) {
      my $command = $DCBCommon::registry->{commands}->{$commands};
      if ($commands =~ $DCBCommon::registry->{commands}->{$commands}->{name}) {
        if (user_access($user, $command->{permissions})) {
          $message .= DCBCommon::common_escape_string("$DCBSettings::config->{cp}") . "$command->{name}: $command->{description}\n";
        }
      }
    }
  }

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

1;
