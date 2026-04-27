package help;

use strict;
use warnings;
use FindBin;
use DCBCommon;
use DCBSettings;
use DCBUser;
use lib "$FindBin::Bin/..";

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();
  my $cp = DCBSettings::config_get('cp');
  my $bot_name = DCBSettings::config_get('botname');
  my $hub_name = DCBSettings::config_get('hubname');

  my $message = "";

  if ($chat && $chat =~ /\S/) {
    # Specific command help: -help <command>
    my $cmd_name = lc($chat);
    $cmd_name =~ s/^\s+|\s+$//g;
    my $cmd = $DCBCommon::registry->{commands}->{$cmd_name};
    if ($cmd) {
      $message = "Help for ${cp}${cmd_name}:\n";
      $message .= "  Description: $cmd->{description}\n" if $cmd->{description};
      if ($cmd->{permissions}) {
        my $perms = ref($cmd->{permissions}) eq 'ARRAY'
          ? join(', ', @{$cmd->{permissions}})
          : $cmd->{permissions};
        $message .= "  Permissions: $perms\n";
      }
      if ($cmd->{alias}) {
        my $aliases = ref($cmd->{alias}) eq 'ARRAY'
          ? join(', ', map { "${cp}$_" } @{$cmd->{alias}})
          : "${cp}$cmd->{alias}";
        $message .= "  Aliases: $aliases\n";
      }
    }
    else {
      $message = "Unknown command '${cp}${cmd_name}'. Use ${cp}help for a list of commands.";
    }
  }
  else {
    # General help: list all commands the user can access
    $message = "=== $hub_name - $bot_name Commands ===\n\n";

    my %seen;
    my @commands;
    foreach my $name (sort keys %{$DCBCommon::registry->{commands}}) {
      my $cmd = $DCBCommon::registry->{commands}->{$name};
      # Skip aliases (they point to the same command with a different name)
      next if $seen{$cmd->{description} // ''}++;
      # Skip system/hidden commands
      next if $cmd->{system};
      # Check permissions
      if ($cmd->{permissions} && ref($cmd->{permissions}) eq 'ARRAY') {
        my $has_access = 0;
        foreach my $perm (@{$cmd->{permissions}}) {
          if (PERMISSIONS->{$perm} && user_access($user, PERMISSIONS->{$perm})) {
            $has_access = 1;
            last;
          }
        }
        next unless $has_access;
      }
      push @commands, $cmd;
    }

    foreach my $cmd (@commands) {
      my $desc = $cmd->{description} // '';
      $message .= sprintf("  ${cp}%-15s %s\n", $cmd->{name}, $desc);
    }

    $message .= "\nUse ${cp}help <command> for detailed help on a specific command.";
  }

  @return = (
    {
      param    => "message",
      message  => "$message",
      user     => $user->{'name'},
      touser   => '',
      type     => MESSAGE->{PUBLIC_SINGLE},
    },
  );
  return @return;
}

1;
