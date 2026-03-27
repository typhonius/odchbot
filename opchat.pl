#!/usr/bin/perl

#--------------------------
# OPChat - Extendable, Hookable, Plugable
#
# If in doubt, read the README
#--------------------------
use strict;
use warnings;

use Time::HiRes qw(gettimeofday tv_interval);
my $start_time = [gettimeofday()];
use Text::Tabs;
use FindBin;
use lib "$FindBin::Bin";
use Log::Log4perl qw(:levels);

use DCBCommon;
use DCBSettings;
use DCBUser;

# Enable the logger and load configuration.
# Read config and resolve relative paths against the script's directory so
# the embedded Perl inside opendchub works regardless of the hub's CWD.
{
  open my $fh, '<', "$FindBin::Bin/opchat.log4perl.conf"
    or die "Cannot open $FindBin::Bin/opchat.log4perl.conf: $!";
  my $conf = do { local $/; <$fh> };
  close $fh;
  $conf =~ s{^(log4perl\.appender\.\w+\.filename=)(?!/)(.+)$}{$1$FindBin::Bin/$2}mg;
  Log::Log4perl->init(\$conf);
}
my $logger = Log::Log4perl->get_logger('OPChat');

my $oplist = {};

eval {
  our $Settings = DCBSettings->new();
  $Settings->config_init('opchat.yml');

  if ($DCBSettings::config->{debug}) {
    $logger->level($DEBUG);
    $logger->debug("Debug mode enabled.");
  }
};
if ($@) {
  $logger->error($@);
  die;
}

sub main {
  our $c = DCBCommon::common_escape_string("$DCBSettings::config->{cp}");
  odch::register_script_name($DCBSettings::config->{botname});
  my $loadtime = tv_interval ( $start_time ) ;
  $logger->debug("$DCBSettings::config->{botname} version $DCBSettings::config->{version} - loaded in $loadtime seconds!");
}

sub data_arrival {
  my ($name, $data) = @_;
  my $botname = $DCBSettings::config->{botname};
  $data =~ s/[\r\n]+/ /g;
  # matches PM
  if ($data =~ /^\$To:\s\Q$botname\E\sFrom:\s$name\s\$\<\Q$name\E\>\s(.*)\|/) {
    my $chat = $1;
    my $user = $oplist->{lc($name)};
    opchat_sendtoopchat($name, $chat);
    if ($chat =~ /^(?:$::c)add\s?(\S+)/ && $user && user_is_admin($user)) {
      my @chatarray = split(/\s+/, $1);
      my $invitee = shift(@chatarray);
      if (lc($invitee) eq lc($botname)) {
        opchat_sendtoopchat($botname, "Cannot add the bot to chat.");
      }
      elsif ($oplist->{lc($invitee)}) {
        opchat_sendtoopchat($botname, "$invitee is already in chat.");
      }
      else {
        my %user = (
          'name' => $invitee,
          'permission' => PERMISSIONS->{AUTHENTICATED},
        );
        $oplist->{lc($invitee)} = \%user;
        $logger->debug("Added $invitee to oplist.");
        opchat_sendtoopchat($botname, "Added $invitee to chat!");
      }
    }
    elsif ($chat =~ /^(?:$::c)remove\s?(\S+)/ && $user && user_is_admin($user)) {
      my @chatarray = split(/\s+/, $1);
      my $rejectee = shift(@chatarray);
      if ($oplist->{lc($rejectee)}) {
        if (!user_is_admin($oplist->{lc($rejectee)})) {
          delete $oplist->{lc($rejectee)};
          $logger->debug("Removed $rejectee from oplist.");
          opchat_sendtoopchat($botname, "Removed $rejectee from chat!");
        }
      }
    }
    elsif ($chat =~ /^(?:$::c)list$/ && $user && user_is_admin($user)) {
      my %permissions;
      foreach my $key (sort keys %{+PERMISSIONS}) {
        $permissions{PERMISSIONS->{$key}} = $key;
      }
      my $message = "List of users in this chat\n";
      foreach my $op (keys %{$oplist}) {
        $message .= "[$permissions{$oplist->{$op}->{permission}}] $op\n";
      }
      opchat_sendtoopchat($botname, $message);
    }
    elsif ($chat =~ /^(?:$::c)commands$/ && $user && user_is_admin($user)) {
      my $message = "$botname commands:\n";
      $message .= "-add: Adds a user to this chat. Usage -add <username>\n";
      $message .= "-remove: Removes a user from this chat. Usage -remove <username>\n";
      $message .= "-list: Shows the list of users in this chat.\n";
      $message .= "-commands: Shows these commands.\n";
      opchat_sendtoopchat($botname, $message);
    }
  }
}

sub op_admin_connected {
  my ($user) = @_;
  $logger->debug("$user connected as admin");
  opchat_login($user, PERMISSIONS->{ADMINISTRATOR});
}
sub op_connected {
  my ($user) = @_;
  $logger->debug("$user connected as op");
  opchat_login($user, PERMISSIONS->{OPERATOR});
}
sub reg_user_connected {
  my ($user) = @_;
  $logger->debug("$user connected as registered user");
  opchat_login($user, PERMISSIONS->{AUTHENTICATED});
}
sub new_user_connected {
  my ($user) = @_;
  $logger->debug("$user connected as new user");
  opchat_login($user, PERMISSIONS->{ANONYMOUS});
}
sub user_disconnected {
  my ($name) = @_;
  $logger->debug("$name disconnected.");
  delete $oplist->{lc($name)};
}

sub opchat_login {
  my ($name, $permission) = @_;

  my %user = (
    'name' => $name,
    'permission' => $permission,
  );
  if (user_is_admin(\%user)) {
    $logger->debug("Automatically adding $name to oplist.");
    $oplist->{lc($name)} = \%user;
  }

  my $tag = "$DCBSettings::config->{bottag} V:$DCBSettings::config->{version},M:P,H:1/3/3,S:7";
  my $botmessage = "\$MyINFO \$ALL $DCBSettings::config->{botname} " .
    "$DCBSettings::config->{botdescription}<$tag>\$\$\$$DCBSettings::config->{botspeed}>" .
    "\$$DCBSettings::config->{botemail}\$$DCBSettings::config->{botshare}\$";
  odch::data_to_user($name, $botmessage."|");
}

sub opchat_sendtoopchat {
  my ($name, $message) = @_;
  $message =~ s/\r?\n/\r\n/g;
  $message =~ s/\|/&#124;/g;
  $message = expand($message);
  my $botname = $DCBSettings::config->{botname};
  if ($name eq $botname || ($oplist->{lc($name)} && $oplist->{lc($name)}->{name} eq $name)) {
    foreach my $op (keys %{$oplist}) {
      unless (lc($name) eq $op) {
        my $real_nick = $oplist->{$op}->{name};
        odch::data_to_user($real_nick, "\$To: $real_nick From: $botname \$<$name> $message|");
      }
    }
  }
}

# Exit cleanly for CI boot test

exit 0;
