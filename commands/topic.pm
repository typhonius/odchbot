package topic;

use strict;
use warnings;
use DCBSettings;
use DCBUser;
use FindBin;
use lib "$FindBin::Bin/..";

sub init {
  return topic_return_topic();
}

sub schema {
  my %schema = (
    config => {
      topic => "Dragon's Topic",
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @output = ();

  if ($chat && (user_access($user, DCBUser::PERMISSIONS->{ADMINISTRATOR}) || user_access($user, DCBUser::PERMISSIONS->{OPERATOR}))) {
    DCBSettings::config_set('topic', $chat);
    push(@output, topic_return_topic());
  }
  push(@output, topic_return_topic(4, $user));

  return @output;
}

sub topic_return_topic {
  my $type = shift;
  my $user = shift;
  $type ||= 1;
  my $topic = DCBSettings::config_get('topic');
  my $message = ($type == 1 || $type == 11) ? "\$HubName $topic" : "Hub topic: $topic";

  my @return = (
    {
      param    => "message",
      message  => $message,
      touser   => '',
      user     => $user ? $user->{'name'} : '',
      type     => $type,
    },
  );
  return @return;
}

sub postlogin {
  my $command = shift;
  my $user = shift;
  my @return = topic_return_topic(11, $user);
  push (@return, topic_return_topic(2, $user));
  return @return;
}

1;