package quote;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBDatabase;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @chatarray = split(/\s+/, $chat);
  my $target_name = shift(@chatarray);
  my $message = '';

  # Build query - optionally filter by username
  my @fields = ('uid', 'chat', 'time');
  my %where = ();

  if ($target_name) {
    my $target = DCBUser::user_load_by_name($target_name);
    if ($target && $target->{uid}) {
      $where{uid} = $target->{uid};
    }
    else {
      $message = "Unknown user: $target_name";
    }
  }

  if (!$message) {
    # Get a random quote by selecting with random order, limit 1
    # SQL::Abstract::Limit handles the LIMIT clause
    my $sth = DCBDatabase::db_select('history', \@fields, \%where, \'RANDOM()', 1);
    my $row = $sth->fetchrow_hashref();

    if ($row) {
      my $author = DCBUser::user_load($row->{uid});
      my $author_name = $author->{name} || 'Unknown';
      my $time = DCBCommon::common_timestamp_time($row->{time});
      $message = "\"$row->{chat}\"\n  -- $author_name ($time)";
    }
    else {
      $message = "No chat history found" . ($target_name ? " for $target_name" : "");
    }
  }

  my @return = (
    {
      param   => "message",
      message => $message,
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

1;
