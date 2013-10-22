package topic;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;

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
  push(@output, topic_return_topic(MESSAGE->{'PUBLIC_ALL'}, $user));

  return @output;
}

sub topic_return_topic {
  my $type = shift;
  my $user = shift;
  $type ||= MESSAGE->{'HUB_PUBLIC'};
  my $topic = DCBSettings::config_get('topic');
  my $message = ($type == MESSAGE->{'HUB_PUBLIC'} || $type == MESSAGE->{'RAW'}) ? "\$HubName $topic" : "Hub topic: $topic";

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
  my @return = topic_return_topic(MESSAGE->{'RAW'}, $user);
  push (@return, topic_return_topic(MESSAGE->{'PUBLIC_SINGLE'}, $user));
  return @return;
}

1;