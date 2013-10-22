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

  # TODO add in historical high and low data

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
  db_insert('stats', $stats);
  return;
}


1;
