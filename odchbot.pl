#!/usr/bin/perl

#--------------------------
# ODCH Bot - Extendable, Hookable, Plugable
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

use DCBSettings;
use DCBDatabase;
use DCBCommon;
use DCBUser;

our $VERSION = '3.0.2';

# Enable the logger and load configuration.
# Read config and resolve relative paths against the script's directory so
# the embedded Perl inside opendchub works regardless of the hub's CWD.
{
  open my $fh, '<', "$FindBin::Bin/odchbot.log4perl.conf"
    or die "Cannot open $FindBin::Bin/odchbot.log4perl.conf: $!";
  my $conf = do { local $/; <$fh> };
  close $fh;
  $conf =~ s{^(log4perl\.appender\.\w+\.filename=)(?!/)(.+)$}{$1$FindBin::Bin/$2}mg;
  Log::Log4perl->init(\$conf);
}
my $logger = Log::Log4perl->get_logger('ODCH Bot');

our $odch_dispatch_table ||= {
  ip => \&odch::get_ip,
  share   => \&odch::get_share,
  variable   => \&odch::get_variable,
  types   => \&odch::get_types,
  description => \&odch::get_description,
  count_users => \&odch::count_users,
  user_list => \&odch::get_user_list,
  (exists &odch::is_tls ? (is_tls => \&odch::is_tls) : ()),
};

eval {
  our $Settings = DCBSettings->new();
  $Settings->config_init('odchbot.yml');

  our $Database = DCBDatabase->new();
  $Database->db_init();

  our $Common = DCBCommon->new();
  $Common->common_init();
  $Common->commands_init();

  our $User = DCBUser->new();
  # During testing this function should not try to call an odch function.
  my $user_list = exists &odch::data_to_all ? odch_get('user_list') : '';
  $User->user_init($user_list);

  odch_hooks('init');

  if ($DCBSettings::config->{debug}) {
    use Data::Dumper;
    $logger->level($DEBUG);
    $logger->debug("Debug mode enabled.");
    odch_sendmessage("","",4,"Debug mode enabled.");
  }
};
if ($@) {
  odch_sendmessage("","",4,"$@");
  $logger->error($@);
  die;
}

sub main() {
  our $c = DCBCommon::common_escape_string("$DCBSettings::config->{cp}");
  odch::register_script_name($DCBSettings::config->{botname});
  odch_sendmessage("","",1,"\$HubName $DCBSettings::config->{topic}");
  my $loadtime = tv_interval ( $start_time ) ;
  odch_sendmessage("","",4,"$DCBSettings::config->{botname} version $VERSION - loaded in $loadtime seconds!");
  $logger->debug("$DCBSettings::config->{botname} version $VERSION - loaded in $loadtime seconds!");
}

sub data_arrival() {
  my ($name, $data) = @_;
  eval {
    $data =~ s/[\r\n]+/ /g;
    my $user = $DCBUser::userlist->{lc($name)};
    if (!$user) {
      # User not in userlist yet (race condition or internal user) — skip
      return;
    }
    if ($data =~ /^\$MyPass\s(.*)/) {
      # Whenever a registered user enters this is their password
      my $password = $1;
    }
    elsif ($data =~ /^\$Search/) {
      $DCBCommon::COMMON->{stats}->{hubstats}->{searches}++;
    }
    elsif ($data =~ /^\<\Q$name\E\>\s(.*)\|/) {
      my $chat = $1;
      odch_hooks('line', $user, $chat);
      if ($chat =~ /^(?:$::c)(\w+)\s?(.*)/) {
        my $command = $1;
        my $params = $2 ? $2 : '';
        if ($DCBCommon::registry->{commands}->{$command}) {
          if (user_access($user, $DCBCommon::registry->{commands}->{$command}->{permissions})) {
            my @return = DCBCommon::commands_run_command($DCBCommon::registry->{commands}->{$command}, 'main', $user, $params);
            odch_respond(@return);
          }
        }
      }
    }
    elsif ($data =~ /^\$To:\s(\w+)\sFrom:\s$name\s\$\<\Q$name\E\>\s(.*)\|/) {
      my $touser = $1;
      my $chat = $2;
      my @params = ($touser, $chat);
      odch_hooks('pm', $user, \@params);
    }
  };
  $logger->error("data_arrival error: $@") if $@;
}

sub attempted_connection() {
  # Block any banned IPs
  my ($hostname) = @_;
}

sub op_admin_connected() {
  my ($user, $conn_type) = @_;
  eval {
    $logger->debug("$user connected as admin ($conn_type)");
    odch_login($user, PERMISSIONS->{ADMINISTRATOR}, $conn_type);
  };
  $logger->error("op_admin_connected error for $user: $@") if $@;
}
sub op_connected() {
  my ($user, $conn_type) = @_;
  eval {
    $logger->debug("$user connected as op ($conn_type)");
    odch_login($user, PERMISSIONS->{OPERATOR}, $conn_type);
  };
  $logger->error("op_connected error for $user: $@") if $@;
}
sub reg_user_connected() {
  my ($user, $conn_type) = @_;
  eval {
    $logger->debug("$user connected as registered user ($conn_type)");
    odch_login($user, PERMISSIONS->{AUTHENTICATED}, $conn_type);
  };
  $logger->error("reg_user_connected error for $user: $@") if $@;
}
sub new_user_connected() {
  my ($user, $conn_type) = @_;
  eval {
    $logger->debug("$user connected as new user ($conn_type)");
    odch_login($user, PERMISSIONS->{ANONYMOUS}, $conn_type);
  };
  $logger->error("new_user_connected error for $user: $@") if $@;
}

sub odch_login() {
  my ($name, $permission, $conn_type) = @_;

  # from the database but new users will only have the $user->{'name'}
  my $user = user_load_by_name($name);
  $user->{'permission'} = $permission;
  $user->{'new'} = defined($user->{'uid'}) ? 0 : 1;
  if ($user->{'new'}) {
    $user->{'join_time'} = time();
    $user->{'join_share'} = odch_get('share', $user->{'name'});
  }
  $user->{'connect_time'} = time();
  $user->{'connect_share'} = odch_get('share', $user->{'name'});
  $user->{'ip'} = odch_get('ip', $user->{'name'});
  $user->{'client'} = odch_get('description', $user->{name});
  # TLS status: prefer XS function (checks actual SSL state), fall back to callback arg
  if (exists &odch::is_tls) {
    $user->{'conn_type'} = odch::is_tls($user->{name}) ? 'tls' : 'plain';
  } else {
    $user->{'conn_type'} = $conn_type || 'plain';
  }

  my @errors = ();
  @errors = user_check_errors($user);

  if (@errors) {
    my $error_string = join("\n", @errors);
    $logger->debug("$error_string. Structure: ", { filter => \&Dumper, value  => $user });
    odch_sendmessage($user->{name}, "", 2, $error_string);
    odch_odch('kick', $user->{name});
    return;
  }

  # If prelogin returns something, a command has declared the user unfit to log in.
  my @prelogin = odch_hooks('prelogin', $user);
  if (scalar(@prelogin) != 0) {
    $logger->debug("Prelogin error. Structure: ", { filter => \&Dumper, value  => $user });
    return;
  }

  my $tag = "$DCBSettings::config->{bottag} V:$VERSION,M:P,H:1/3/3,S:7";
  odch_sendmessage($user->{name}, "", 11, "\$MyINFO \$ALL $DCBSettings::config->{botname} " .
    "$DCBSettings::config->{botdescription}<$tag>\$\$\$$DCBSettings::config->{botspeed}>" .
    "\$$DCBSettings::config->{botemail}\$$DCBSettings::config->{botshare}\$");

  # The user has been accepted so save their details to the db and welcome them.
  user_connect($user);

  # if it's all ok then add to the userlist - should this happen in user module?
  $DCBUser::userlist->{lc($user->{name})} = $user;
  $DCBCommon::COMMON->{stats}->{hubstats}->{connections}++;
  $DCBCommon::COMMON->{stats}->{hubstats}->{total_share} = odch_get('variable', 'total_share');
  $DCBCommon::COMMON->{stats}->{hubstats}->{number_users} = odch::count_users();

  odch_hooks('postlogin', $user);
}

sub user_disconnected() {
  my ($name) = @_;
  eval {
    $logger->debug("$name disconnected.");
    my $user = $DCBUser::userlist->{lc($name)};
    if (!$user) {
      # User was never in userlist (kicked during prelogin, or internal user)
      return;
    }
    $user->{disconnect_time} = time();
    user_disconnect($user);
    odch_hooks('logout', $user);
    delete $DCBUser::userlist->{lc($name)};
    $DCBCommon::COMMON->{stats}->{hubstats}->{disconnections}++;
    $DCBCommon::COMMON->{stats}->{hubstats}->{total_share} = odch_get('variable', 'total_share');
    $DCBCommon::COMMON->{stats}->{hubstats}->{number_users} = odch::count_users();
  };
  $logger->error("user_disconnected error for $name: $@") if $@;
}

sub odch_hooks {
  my $hook = shift;
  my $user = shift;
  my $params = shift;
  my @return = ();

  if ($DCBCommon::registry->{hooks}->{$hook}) {
    foreach my $commandname (keys %{$DCBCommon::registry->{hooks}->{$hook}}) {
      my $command = $DCBCommon::registry->{commands}->{$commandname};
      ($command, $hook, $user, $params) = odch_alter($command, $hook, $user, $params);
      my @result = DCBCommon::commands_run_command($command, $hook, $user, $params);
      push(@return, grep { ref($_) eq 'HASH' } @result);
    }
    odch_respond(@return);
  }
  return @return;
}

sub odch_alter {
  my ($command, $hook, $user, $params) = @_;
  if ($DCBCommon::registry->{hooks}->{alter}) {
    foreach my $alter (keys %{$DCBCommon::registry->{hooks}->{alter}}) {
      my $altercommand = $DCBCommon::registry->{commands}->{$alter};
      my @params = ($command, $hook, $params);
      DCBCommon::commands_run_command($altercommand, 'alter', $user, \@params);
    }
  }
  return ($command, $hook, $user, $params);
}

sub odch_respond {
  my @return = @_;

  foreach (@return) {
    next unless ref($_) eq 'HASH';
    if ($_->{param} eq "message") {
        odch_sendmessage($_->{user}, $_->{fromuser}, $_->{type}, $_->{message});
      }
      elsif ($_->{param} eq "action") {
        odch_odch($_->{action}, $_->{user}, $_->{arg});
      }
      elsif ($_->{param} eq "log") {
        $logger->debug("Structure: ", { filter => \&Dumper, value  => $_ });
      }
  }
}

sub odch_get {
  my ($action, $param) = @_;
  if (defined($param)) {
    return $odch_dispatch_table->{$action}->($param);
  }
  else {
    return $odch_dispatch_table->{$action}->();
  }
}

sub odch_odch {
  my($odch_func, $user, $arg) = @_;
  if ($odch_func eq "kick") {
      odch::kick_user($user);
    }
    elsif ($odch_func eq "nickban") {
      odch::add_nickban_entry("$user $arg");
      odch::kick_user($user);
    }
    elsif ($odch_func eq "unnickban") {
      odch::remove_nickban_entry($user);
    }
    elsif ($odch_func eq "gag") {
      odch::add_gag_entry("$user $arg");
    }
    elsif ($odch_func eq "ungag") {
      odch::remove_gag_entry($user);
    }
    # elsif ($odch_func eq "set") {
    #   odch::set_variable($arg);
    # }
}

sub hub_timer() {
  eval {
    $logger->debug('Hub timer fired.');
    odch_hooks('timer');
    $DCBCommon::COMMON->{variables}->{hub_timer_last_run} = time();
  };
  $logger->error("hub_timer error: $@") if $@;
}

sub odch_sendmessage {
  my ($user, $fromuser, $type, $message) = @_;
  $message =~ s/\r?\n/\r\n/g;
  $message =~ s/\|/&#124;/g;
  $message = expand($message);
  if ($message && $type && exists &odch::data_to_all) {
    my $botname = $DCBSettings::config->{botname};

    if ($type == MESSAGE->{'HUB_PUBLIC'}) { odch::data_to_all($message."|"); }
      elsif ($type == MESSAGE->{'PUBLIC_SINGLE'}) { odch::data_to_user($user, "<$botname> $message|"); }
      elsif ($type == MESSAGE->{'BOT_PM'}) { odch::data_to_user($user, "\$To: $user From: $botname \$<$botname> $message|"); }
      elsif ($type == MESSAGE->{'PUBLIC_ALL'}) {
        odch::data_to_all("<$botname> $message|");
        my $bot = ();
        $bot->{uid} = 1 ;
        odch_hooks('line', $bot, $message);
      }
      elsif ($type == MESSAGE->{'MASS_MESSAGE'}) { odch::data_to_all("\$To: $user From: $botname \$<$botname> $message|"); }
      elsif ($type == MESSAGE->{'SPOOF_PM_BOTH'}) {
        odch::data_to_user($user,"\$To: $user From: $fromuser \$$message|");
        odch::data_to_user($fromuser,"\$To: $fromuser From: $user \$$message|");
      }
      elsif ($type == MESSAGE->{'SEND_TO_OPS'}) { odch_sendtoops($botname, "$message|"); }
      elsif ($type == MESSAGE->{'HUB_PM'}) { odch::data_to_user($user,"\$To: $user From: $botname \$$message|"); }
      elsif ($type == MESSAGE->{'SPOOF_PM_SINGLE'}) { odch::data_to_user($user,"\$To: $user From: $fromuser \$<$fromuser> $message|"); }
      elsif ($type == MESSAGE->{'SPOOF_PUBLIC'}) {
        odch::data_to_all("<$user> $message|");
        #$DCBUser::userlist->{$name} name could be fake so put 0 here if need to
      }
      elsif ($type == MESSAGE->{'RAW'}) { odch::data_to_user($user, $message."|"); }
      elsif ($type == MESSAGE->{'SEND_TO_ADMINS'}) { odch_sendtoadmins($botname, "$message|"); }
      else { odch::data_to_all("<$botname> INCORRECT TYPE ERROR|"); }
  }
}

sub odch_sendtoops() {
  my ($botname, $message) = @_;
  foreach (split(/\s+/, odch_get('user_list'))) {
    if (user_access($DCBUser::userlist->{lc($_)}, (PERMISSIONS->{ADMINISTRATOR} | PERMISSIONS->{OPERATOR}))) {
      odch_sendmessage("$_", "", "8", "$message");
    }
  }
}

sub odch_sendtoadmins() {
  my ($botname, $message) = @_;
  foreach (split(/\s+/, odch_get('user_list'))) {
    if (user_access($DCBUser::userlist->{lc($_)}, (PERMISSIONS->{ADMINISTRATOR}))) {
      odch_sendmessage("$_", "", "8", "$message");
    }
  }
}

# Additional subroutine and exit to allow exit 0 and happy travis-ci

exit 0;
