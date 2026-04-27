package stats;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use Clone qw(clone);
use DCBCommon;
use DCBDatabase;

sub schema {
  my %schema = (
    schema => ({
      stats => {
        sid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        time => { type => "INT", },
        number_users  => { type => "INT", },
        total_share => { type => "BLOB", },
        connections => { type => "INT", },
        disconnections => { type => "INT", },
        searches => { type => "INT", },
      },
    }),
  );
  return \%schema;
}

sub init {
  my %where = ();
  my @fields = ('*');
  my $order = {-desc => 'sid'};
  my $statsh = DCBDatabase::db_select('stats', \@fields, \%where, $order);

  my $stats = $statsh->fetchrow_hashref();
  if (!$stats) {
    my %fields = ( 'time' => time(), number_users => 0, total_share => 0, connections => 0, disconnections => 0, searches => 0 );
    DCBDatabase::db_insert( 'stats', \%fields );
    $stats = \%fields;
  }

  $DCBCommon::COMMON->{stats}->{hubstats} = $stats;

  # Load historical highs
  my @max_fields = ('MAX(number_users) AS max_users', 'MAX(total_share) AS max_share');
  my %max_where = ();
  my $maxh = DCBDatabase::db_select('stats', \@max_fields, \%max_where);
  my $max = $maxh->fetchrow_hashref();
  $DCBCommon::COMMON->{stats}->{max_users} = $max->{max_users} // 0;
  $DCBCommon::COMMON->{stats}->{max_share} = $max->{max_share} // 0;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();

  my $message = "Hub Stats at " . DCBCommon::common_timestamp_time($DCBCommon::COMMON->{stats}->{hubstats}->{time}) . "\n";
  $message .= "Connections => $DCBCommon::COMMON->{stats}->{hubstats}->{connections}\n";
  $message .= "Disconnections => $DCBCommon::COMMON->{stats}->{hubstats}->{disconnections}\n";
  $message .= "Total Share => " . DCBCommon::common_format_size($DCBCommon::COMMON->{stats}->{hubstats}->{total_share}) . "\n";
  $message .= "User Number => $DCBCommon::COMMON->{stats}->{hubstats}->{number_users}\n";
  $message .= "Searches => $DCBCommon::COMMON->{stats}->{hubstats}->{searches}\n";
  $message .= "Historical High Users => $DCBCommon::COMMON->{stats}->{max_users}\n";
  $message .= "Historical High Share => " . DCBCommon::common_format_size($DCBCommon::COMMON->{stats}->{max_share}) . "\n";

  @return = (
    {
      param    => "message",
      message  => "$message",
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_SINGLE'},
    },
  );
  return @return;
}

sub timer {
  my $stats = clone ($DCBCommon::COMMON->{stats}->{hubstats});
  delete($stats->{sid});
  $stats->{time} = time();
  DCBDatabase::db_insert('stats', $stats);
  return;
}


1;
