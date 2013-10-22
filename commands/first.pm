package first;

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
  my $first_user_name = shift;
  $first_user_name ||= $user->{'name'};

  my @return = ();
  my $first_user = user_load_by_name($first_user_name);
  my $message = "";
  if ($first_user->{'uid'}) {
    my @fields = ('time', 'uid', 'chat');
    my %where = ('uid' => $first_user->{'uid'});
    my $order = {-asc => 'hid'};
    my $limit = 1;
    my $firsth = DCBDatabase::db_select('history', \@fields, \%where, $order, $limit);
    while (my $first = $firsth->fetchrow_hashref()) {
      $message = "First line spoken by $first_user->{'name'}: \n[" . DCBCommon::common_timestamp_time($first->{time}) . "] <$first_user->{name}>: $first->{chat}\n";
    }
    if (!$message) {
      $message = $first_user->{'name'} . " has never spoken; boring!"
    }
  }
  else {
    $message = "User '$first_user_name' does not exist;"
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

1;
