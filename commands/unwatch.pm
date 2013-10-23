package unwatch;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;
use DCBDatabase;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @chatarray = split(/\s+/, $chat);
  my $watched_user = @chatarray ? $DCBUser::userlist->{lc(shift(@chatarray))} : '';

  my @return = ();
  my $message = '';

  if ($watched_user) {
    if (grep $_ eq $watched_user->{'uid'}, unwatch_get_watching($user)) {
      my %where = ('uid' => $user->{'uid'}, 'watched_uid' => $watched_user->{'uid'});
      DCBDatabase::db_delete('watch', \%where);
      $message = "You are now no longer watching $watched_user->{name}.";
    }
    else {
      $message = "You are not currently watching $watched_user->{name}.";
    }
  }
  else {
    $message = 'User does not exist.';
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

  return(@return);
}

sub unwatch_get_watching {
  my $user = shift;
  my @fields = ('uid', 'watched_uid');
  my %where = ('uid' => $user->{uid});
  my $watchh = DCBDatabase::db_select('watch', \@fields, \%where);
  my @return = ();
  while (my $watch = $watchh->fetchrow_hashref()) {
    push(@return, $watch->{watched_uid});
  }
  return @return;
}

1;
