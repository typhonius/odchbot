package history;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw(min);
use Scalar::Util qw(looks_like_number);
use DCBSettings;
use DCBCommon;
use DCBDatabase;
use DCBUser;

sub schema {
  my %schema = (
    schema => ({
      history => {
        hid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        time => { type => "INT", },
        uid  => { type => "INT", },
        chat => { type => "BLOB", },
      },
    }),

    config => {
      history_default => 10,
      history_max => 100,
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $limit = shift;
  
  $limit = looks_like_number($limit) ? min $limit, $DCBSettings::config->{'history_max'} : $DCBSettings::config->{'history_default'}; 

  my @return = ();
  my $message = "Chat history: \n";
  my @fields = ('time', 'uid', 'chat');
  my %where = ();
  my $order = {-desc => 'hid'};
  my %user_cache = ();
  my $historyh = DCBDatabase::db_select('history', \@fields, \%where, $order, $limit);
  my @inverse_history = ();
  while (my $history = $historyh->fetchrow_hashref()) {
    # So we don't have to load the user for _each_ line we implement
    # a basic cache to only load each unique user once.
    if (!$user_cache{$history->{uid}}) {
      $user_cache{$history->{uid}} = user_load($history->{uid});
    }
    push(@inverse_history, "[" . DCBCommon::common_timestamp_time($history->{time}) . "] <$user_cache{$history->{uid}}->{name}>: $history->{chat}\n");
  }
  foreach (reverse @inverse_history) {
    $message .= $_;
  }

  @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_SINGLE'},
    },
  );
  return @return;
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();
  unless ($chat =~ /^!.*/) {
    my %fields = (
      'time' => time(),
      'uid' => $user->{uid},
      'chat' => $chat,
    );
    DCBDatabase::db_insert('history', \%fields);
#     # Insert into flag file for live chat
#     #open( FLAG, '>' . $config{scriptPath} . 'flagfile');
#     #print FLAG '<' . $user . '> ' . $chat;
#     #close (FLAG);
  }

  return;
}

1;
