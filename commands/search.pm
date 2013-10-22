package search;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;

sub schema {
  my %schema = (
    config => {
      search_min_length => 5,
      search_return_limit => 100,
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $search = shift;

  my $message = '';

  if (length($search) < $DCBSettings::config->{search_min_length}) {
    $message = "Don't kill me :''( search for a longer string."
  }
  else {
    $message = "Chat history: \n";
    my @fields = ('time', 'uid', 'chat');

    # Ensure we do not search for what the bot puts back into chat
    my %where = (
      chat => { '-like', '%' . $search . '%' },
      uid => { '!=', 2 }
    );
    my $order = {-desc => 'hid'};
    my %user_cache = ();
    my $historyh = DCBDatabase::db_select('history', \@fields, \%where, $order, $DCBSettings::config->{search_return_limit});
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
  }


  my @return = ();

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

1;
