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
use Switch;
use Text::Tabs;
use FindBin;
use lib "$FindBin::Bin";
use Log::Log4perl qw(:levels);

use DCBSettings;
use DCBDatabase;
use DCBCommon;
use DCBUser;

# Enable the logger and load configuration.
Log::Log4perl->init('odchbot.log4perl.conf');
my $logger = Log::Log4perl->get_logger('ODCH Bot');

our $odch_dispatch_table ||= {
  ip => \&odch::get_ip,
  share   => \&odch::get_share,
  variable   => \&odch::get_variable,
  types   => \&odch::get_types,
  description => \&odch::get_description,
  count_users => \&odch::count_users,
  user_list => \&odch::get_user_list,
};

eval {
  our $Settings = new DCBSettings;
  $Settings->config_init('odchbot.yml');

  our $Database = new DCBDatabase;
  $Database->db_init();

  our $Common = new DCBCommon;
  $Common->common_init();
  $Common->commands_init();

  our $User = new DCBUser;
  # During testing this function should not try to call an odch function.
  my $user_list = exists &odch::data_to_all ? odch_get('user_list') : '';
  $User->user_init($user_list);

  odch_hooks('init');

  if ($DCBSettings::config->{debug}) {
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
  odch_sendmessage("","",4,"$DCBSettings::config->{botname} version $DCBSettings::config->{version} - loaded in $loadtime seconds!");
  $logger->debug("$DCBSettings::config->{botname} version $DCBSettings::config->{version} - loaded in $loadtime seconds!");
}

sub data_arrival() {
  my ($name, $data) = @_;
  $data =~ s/[\r\n]+/ /g;
  if ($data =~ /^\$MyPass\s(.*)/) {
    # Whenever a registered user enters this is their password
    my $password = $1;
  }
  elsif ($data =~ /^\$Search/) {
    # odch_hooks('search', $DCBUser::userlist->{lc($name)}, $data);
    $DCBCommon::COMMON->{stats}->{hubstats}->{searches}++;
  }
  elsif ($data =~ /^\<\Q$name\E\>\s(.*)\|/) {
    my $chat = $1;
    # Deal with lines of chat
    odch_hooks('line', $DCBUser::userlist->{lc($name)}, $chat);
    # Deal with commands
    if ($chat =~ /^(?:$::c)(\w+)\s?(.*)/) {
      my $command = $1;
      my $params = $2 ? $2 : '';
      # Check the commands registry to see if this command exists prior to attempting to process.
      if ($DCBCommon::registry->{commands}->{$command}) {
        if (user_access($DCBUser::userlist->{lc($name)}, $DCBCommon::registry->{commands}->{$command}->{permissions})) {
          my @return = DCBCommon::commands_run_command($DCBCommon::registry->{commands}->{$command}, 'main', $DCBUser::userlist->{lc($name)}, $params);
          odch_respond(@return);
        }
      }
    }
  }
  elsif ($data =~ /^\$To:\s(\w+)\sFrom:\s$name\s\$\<\Q$name\E\>\s(.*)\|/) {
    # matches PM
    my $touser = $1;
    my $chat = $2;
    my @params = ($touser, $chat);
    odch_hooks('pm', $DCBUser::userlist->{lc($name)}, \@params);
  }
}

sub attempted_connection() {
  # Block any banned IPs
  my ($hostname) = @_;
}

sub op_admin_connected() {
  my ($user) = @_;
  $logger->debug("$user connected as admin");
  odch_login($user, PERMISSIONS->{ADMINISTRATOR});
}
sub op_connected() {
  my ($user) = @_;
  $logger->debug("$user connected as op");
  odch_login($user, PERMISSIONS->{OPERATOR});
}
sub reg_user_connected() {
  my ($user) = @_;
  $logger->debug("$user connected as registered user");
  odch_login($user, PERMISSIONS->{AUTHENTICATED});
}
sub new_user_connected() {
  my ($user) = @_;
  $logger->debug("$user connected as new user");
  odch_login($user, PERMISSIONS->{ANONYMOUS});
}

sub odch_login() {
  my ($name, $permission) = @_;

  # from the database but new users will only have the $user->{'name'}
  my $user = user_load_by_name($name);
  $user->{'permission'} = $permission;
  $user->{'new'} = !$user->{'uid'} ? 1 : 0;
  if ($user->{'new'}) {
    $user->{'join_time'} = time();
    $user->{'join_share'} = odch_get('share', $user->{'name'});
  }
  $user->{'connect_time'} = time();
  $user->{'connect_share'} = odch_get('share', $user->{'name'});
  $user->{'ip'} = odch_get('ip', $user->{'name'});
  $user->{'client'} = odch_get('description', $user->{name});

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
  if (scalar(@prelogin) == 0) {
    $logger->debug("Prelogin error. Structure: ", { filter => \&Dumper, value  => $user });
    return;
  }

  my $tag = "$DCBSettings::config->{bottag} V:$DCBSettings::config->{version},M:P,H:1/3/3,S:7";
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
  $logger->debug("$name disconnected.");
  my $user = $DCBUser::userlist->{lc($name)};
  $user->{disconnect_time} = time();
  user_disconnect($user);
  odch_hooks('logout', $user);
  $DCBCommon::COMMON->{stats}->{hubstats}->{disconnections}++;
  $DCBCommon::COMMON->{stats}->{hubstats}->{total_share} = odch_get('variable', 'total_share');
  $DCBCommon::COMMON->{stats}->{hubstats}->{number_users} = odch::count_users();
}

sub odch_hooks {
  my $hook = shift;
  my $user = shift;
  my $params = shift;
  my @return = ();

  if ($DCBCommon::registry->{hooks}->{$hook}) {
    foreach my $commandname (keys %{$DCBCommon::registry->{hooks}->{$hook}}) {
      my $command = $DCBCommon::registry->{commands}->{$commandname};
      #($command, $hook, $user, $params) = odch_alter($command, $hook, $user, $params);
      # Wondering if we need to pass the $command object all the way through TODO
      push(@return, DCBCommon::commands_run_command($command, $hook, $user, $params));
    }
    odch_respond(@return);
  }
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
    switch ($_->{param}) {
      case "message" {
        odch_sendmessage($_->{user}, $_->{fromuser}, $_->{type}, $_->{message});
      }
      case "action" {
        odch_odch($_->{action}, $_->{user}, $_->{arg});
      }
      case "log" {
        $logger->debug("Structure: ", { filter => \&Dumper, value  => $_ });
      }
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
  switch($odch_func) {
    case "kick" {
      odch::kick_user($user);
    }
    case "nickban" {
      odch::add_nickban_entry("$user $arg");
      odch::kick_user($user);
    }
    case "unnickban" {
      odch::remove_nickban_entry($user);
    }
    case "gag" {
      odch::add_gag_entry("$user $arg");
    }
    case "ungag" {
      odch::remove_gag_entry($user);
    }
    # case "set" {
    #   odch::set_variable($arg);
    # }
  }
}

sub hub_timer() {
  $logger->debug('Hub timer fired.');
  odch_hooks('timer');
  $DCBCommon::COMMON->{variables}->{hub_timer_last_run} = time();
}

sub odch_sendmessage {
  my ($user, $fromuser, $type, $message) = @_;
  $message =~ s/\r?\n/\r\n/g;
  $message =~ s/\|/&#124;/g;
  $message = expand($message);
  if ($message && $type && exists &odch::data_to_all) {
    my $botname = $DCBSettings::config->{botname};

    switch ($type) {
      case (MESSAGE->{'HUB_PUBLIC'}) { odch::data_to_all($message."|"); }
      case (MESSAGE->{'PUBLIC_SINGLE'}) { odch::data_to_user($user, "<$botname> $message|"); }
      case (MESSAGE->{'BOT_PM'}) { odch::data_to_user($user, "\$To: $user From: $botname \$<$botname> $message|"); }
      case (MESSAGE->{'PUBLIC_ALL'}) {
        odch::data_to_all("<$botname> $message|");
        my $bot = ();
        $bot->{uid} = 1 ;
        odch_hooks('line', $bot, $message);
      }
      case (MESSAGE->{'MASS_MESSAGE'}) { odch::data_to_all("\$To: $user From: $botname \$<$botname> $message|"); }
      case (MESSAGE->{'SPOOF_PM_BOTH'}) {
        odch::data_to_user($user,"\$To: $user From: $fromuser \$$message|");
        odch::data_to_user($fromuser,"\$To: $fromuser From: $user \$$message|");
      }
      case (MESSAGE->{'SEND_TO_OPS'}) { odch_sendtoops($botname, "$message|"); }
      case (MESSAGE->{'HUB_PM'}) { odch::data_to_user($user,"\$To: $user From: $botname \$$message|"); }
      case (MESSAGE->{'SPOOF_PM_SINGLE'}) { odch::data_to_user($user,"\$To: $user From: $fromuser \$<$fromuser> $message|"); }
      case (MESSAGE->{'SPOOF_PUBLIC'}) {
        odch::data_to_all("<$user> $message|");
        #$DCBUser::userlist->{$name} name could be fake so put 0 here if need to
      }
      case (MESSAGE->{'RAW'}) { odch::data_to_user($user, $message."|"); }
      case (MESSAGE->{'SEND_TO_ADMINS'}) { odch_sendtoadmins($botname, "$message|"); }
      else { odch::data_to_all("<$botname> INCORRECT TYPE ERROR|"); }
     }
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
