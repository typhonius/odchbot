#!/usr/bin/env perl

use strict;
use warnings;

#use Log::Log4perl qw(:easy); # Also gives additional debug info back from bot.
use Net::Jabber::Bot;
use Switch;
use Text::Tabs;
use utf8;
binmode(STDOUT, ":utf8");

use DCBSettings;
use DCBDatabase;
use DCBCommon;
use DCBUser;
use Data::Dumper;

eval {
  our $Settings = new DCBSettings;
  $Settings->config_init();

  our $Database = new DCBDatabase;
  $Database->db_init();

  our $Common = new DCBCommon;
  $Common->common_init();
  $Common->commands_init();

  our $User = new DCBUser;
  $User->user_init('');

  # odch_hooks('init');
};
if ($@) {
  #jabber_sendmessage("","",4,"$@");
  #jabber_debug("init","","$@");
  #die;
}

# Init log4perl based on command line options
my %log4perl_init;
$log4perl_init{'cron'}     = 1 if(defined $ARGV{'-cron'});
$log4perl_init{'nostdout'} = 1 if(defined $ARGV{'-nostdout'});
$log4perl_init{'log_file'} = $ARGV{'-logfile'} if(defined $ARGV{'-logfile'});
$log4perl_init{'email'} = $ARGV{'-email'} if(defined $ARGV{'-email'});
$log4perl_init{'debug_level'} = $ARGV{'-debuglevel'};
#InitLog4Perl(%log4perl_init);

our $c = DCBCommon::common_escape_string("$DCBSettings::config->{cp}");

my $jabber = $DCBSettings::config->{jabber};

my %alerts_sent_hash;
my %next_alert_time_hash;
my %next_alert_increment;

my %forums_and_responses;
foreach my $forum (@{ $jabber->{forums} }) {
  my $responses = "bot:|lol hai|"; # Note the pipe at the end indicates it will act on all messages
  my @response_array = split(/\|/, $responses);
  push @response_array, "" if($responses =~ m/\|\s*$/);
  $forums_and_responses{$forum} = \@response_array;
}

my $bot = Net::Jabber::Bot->new(
  from_full              => $jabber->{username} . '@' . $jabber->{domain} . '/' . $jabber->{resource},
  server                 => $jabber->{server},
  conference_server      => $jabber->{conference_server},
  port                   => $jabber->{port},
  username               => $jabber->{username},
  password               => $jabber->{password},
  resource               => $jabber->{resource},
  safety_mode            => 1,
  message_function       => \&new_bot_message,
  background_function    => \&background_checks,
  forums_and_responses   => \%forums_and_responses,
  alias                  => $DCBSettings::config->{botname},
  ignore_server_messages => 1,
  ignore_self_messages   => 1,
);

$bot->ChangeStatus('Available', 'Balling hard');

sub odch_load_roster {
  $DCBCommon::COMMON->{jabber}->{PRESENCE} = $bot->{'jabber_client'}->{'PRESENCEDB'};
  $DCBCommon::COMMON->{jabber}->{ROSTER} = $bot->{'jabber_client'}->{'ROSTERDB'}->{'JIDS'};
}

odch_load_roster();
foreach my $useremail ($bot->GetRoster()) {

  my $username = $DCBCommon::COMMON->{jabber}->{ROSTER}->{$useremail}->{'name'};
  my $user = user_load_by_mail($useremail);
  $user->{'new'} = !$user->{'uid'} ? 1 : 0;
  if ($user->{'new'}) {
    $user->{'name'} = $username;
    $user->{'join_time'} = time();
    $user->{'mail'} = $useremail;
  }
  $user->{'connect_time'} = time();

  # Initiate users with the most basic permission.
  $user->{'permission'} = PERMISSIONS->{AUTHENTICATED};

  # The user has been accepted so save their details to the db and welcome them.
  user_connect($user);

  # if it's all ok then add to the userlist - should this happen in user module?
  $DCBUser::userlist->{lc($user->{mail})} = $user;
}

foreach my $forum (@{ $jabber->{forums} }) {
#    $bot->SendGroupMessage($forum, "$alias logged into $forum");
}

sub background_checks {
# bot_object
#ROSTERDB->JIDS
#PRESENCEDB
}

sub new_bot_message {
  my ($jid, $role) = ('', '');
  my %bot_message_hash = @_;
  my $bot_hash = \%bot_message_hash;

  # Holy shit so much fire if you try and chat directly to the bot.
  if ($bot_message_hash{type} !~ /^groupchat$/) {
    # @TODO put a message direct to the user that what they're doing is wrong?
   # $bot_hash->{sender} = $bot_hash->{from_full};
   # $bot_hash->{sender} =~ s{^.+\/([^\/]+)$}{$1};
   # jabber_sendmessage($bot_hash, '', '', MESSAGE->{'BOT_PM'}, "I'm literally not smart enough to respond to PMs. Find your nearest groupchat to talk to me :''(");
    return;
  }

  $bot_hash->{sender} = $bot_hash->{from_full};
  $bot_hash->{sender} =~ s{^.+\/([^\/]+)$}{$1};
  my $name = $bot_hash->{sender};
  my $chat = $bot_hash->{body};


  # Get the user JID
  # Jabber hands us a horribly convoluted hash of arrays of hashes to work
  # with. The following checks to see if we've already mapped the user's
  # name to their canonical JID and if not, works it out.
  unless ($DCBCommon::COMMON->{jidmap}->{$name}) {
    my %priorities = %{$bot_hash->{'bot_object'}->{'jabber_client'}->{'PRESENCEDB'}->{$bot_message_hash{reply_to}}->{'priorities'}};
    for my $priority (keys %priorities) {
      foreach my $priority_map (@{ $priorities{$priority} }) {
        my $resource = $priority_map->{'resource'};
        foreach my $group_child (@{ $priority_map->{'presence'}->{'TREE'}->{'CHILDREN'} }) {
          foreach my $group_gchild (@{ $group_child->{'CHILDREN'} }) {
            if (defined $group_gchild->{'ATTRIBS'}->{'jid'} && $resource =~ /^$name$/) {
              # Check that the jid contains both '@' and '/'
              # ie adam.malone@acquia.com/resource
              if ($group_gchild->{'ATTRIBS'}->{'jid'} =~ /([\.\w]+)@([\.\w]+)\/(\S+)/) {
                $jid = $group_gchild->{'ATTRIBS'}->{'jid'};
                $role = $group_gchild->{'ATTRIBS'}->{'affiliation'};
                $DCBCommon::COMMON->{jidmap}->{$name}->{jid} = $jid;
                $DCBCommon::COMMON->{jidmap}->{$name}->{role} = $role;
                last;
              }
            }
          }
        }
      }
    }
  }
  else {
    $jid = $DCBCommon::COMMON->{jidmap}->{$name}->{jid};
    $role = $DCBCommon::COMMON->{jidmap}->{$name}->{role} || 'none';
  }

  # If the bot hasn't discovered who the user is already then crash out early.
  if (!$jid) {
    return;
  }

  # Parse out the resource so we're left with just the user email which should
  # be the same as the ID stored in the DB.
  my $user_email = $jid;
  $user_email =~ s{^(.+)\/[^\/]+$}{$1};

  # Try to load user from the user list first, otherwise load from the db.
  my $user;
  if ($DCBUser::userlist->{lc($user_email)}) {
    $user = $DCBUser::userlist->{lc($user_email)};
  }
  else {
    $user = user_load_by_mail($user_email);
  }

  my %role_map = (
    none   => 8,
    member => 8,
    admin  => 16,
    owner  => 32,
  );

  if ($user->{permission} != $role_map{$role}) {
    my %fields = ();
    $fields{permission} = $role_map{$role};
    user_update($user, \%fields);

    $user->{permission} = $role_map{$role};
    $DCBUser::userlist->{lc($user->{mail})} = $user;
  }

  # If the chat is phrased like a command, run that command.
  if ($chat =~ /^(?:$::c)(\w+)\s?(.*)/) {
    my $command = $1;
    my $params = $2 ? $2 : '';
    if ($DCBCommon::registry->{commands}->{$command}) {
      if (user_access($DCBUser::userlist->{lc($user_email)}, $DCBCommon::registry->{commands}->{$command}->{permissions})) {
        my @return = DCBCommon::commands_run_command($DCBCommon::registry->{commands}->{$command}, 'main', $DCBUser::userlist->{lc($user_email)}, $params);
        jabber_respond($bot_hash, @return);
      }
    }
  }
}

sub jabber_respond {
  my ($bot_hash, @return) = @_;

  foreach (@return) {
    switch ($_->{param}) {
      case "message" {
        jabber_sendmessage($bot_hash, $_->{user}, $_->{fromuser}, $_->{type}, $_->{message});
      }
#      case =~ "action" {
#        #odch_odch($_->{action}, $_->{user}, $_->{arg});
#      }
#      case =~ "log" {
#        #odch_debug($_->{action}, $_->{user}, $_->{arg});
#      }
    }
  }
}

sub jabber_sendmessage {
  my ($bot_hash, $user, $fromuser, $type, $message) = @_;
  $message =~ s/\r?\n/\r\n/g;
  $message =~ s/\|/&#124;/g;
  $message = expand($message);

  # Nothing but groupchat
  if ($bot_hash->{type} !~ /^groupchat$/) {
    return
  }

  # Net::Jabber::Bot or XMPP is fucking retarded.
  # https://code.google.com/p/perl-net-jabber-bot/issues/detail?id=24
  my $jid = $DCBCommon::COMMON->{jidmap}->{$bot_hash->{sender}}->{jid};
  foreach (split(/\n/, $message)) {
    switch ($type) {
#      case (MESSAGE->{'HUB_PUBLIC'}) { odch::data_to_all($message."|"); }

      case (MESSAGE->{'PUBLIC_SINGLE'}) { $bot->SendPersonalMessage($jid, $_); }
      case (MESSAGE->{'BOT_PM'}) { $bot->SendPersonalMessage($jid, $_); }
      case (MESSAGE->{'PUBLIC_ALL'}) {
        $bot->SendGroupMessage($bot_hash->{reply_to}, $_);
#        odch::data_to_all("<$botname> $message|");
#        my $bot = ();
#        $bot->{uid} = 1 ;
#        odch_hooks('line', $bot, $message);
      }
#      case (MESSAGE->{'MASS_MESSAGE'}) { odch::data_to_all("\$To: $user From: $botname \$<$botname> $message|"); }
#      case (MESSAGE->{'SPOOF_PM_BOTH'}) {
#        odch::data_to_user($user,"\$To: $user From: $fromuser \$$message|");
#        odch::data_to_user($fromuser,"\$To: $fromuser From: $user \$$message|");
#      }
#      case (MESSAGE->{'SEND_TO_OPS'}) { odch_sendtoops($botname, "$message|"); }
#      case (MESSAGE->{'HUB_PM'}) { odch::data_to_user($user,"\$To: $user From: $botname \$$message|"); }
#      case (MESSAGE->{'SPOOF_PM_SINGLE'}) { odch::data_to_user($user,"\$To: $user From: $fromuser \$<$fromuser> $message|"); }
#      case (MESSAGE->{'SPOOF_PUBLIC'}) {
#        odch::data_to_all("<$user> $message|");
        #$DCBUser::userlist->{$name} name could be fake so put 0 here if need to
#      }
#      case (MESSAGE->{'RAW'}) { odch::data_to_user($user, $message."|"); }
#      case (MESSAGE->{'SEND_TO_ADMINS'}) { odch_sendtoadmins($botname, "$message|"); }
#      else { odch::data_to_all("<$botname> INCORRECT TYPE ERROR|"); }
    }
  }
}

$bot->Start(); #Endless loop where everything happens after initialization.

# DEBUG("Something's gone horribly wrong. Jabber bot exiting...");
exit;


