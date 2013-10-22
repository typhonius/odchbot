package watch;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;
use DCBDatabase;
use DCBUser;

sub schema {
  my %schema = (
    schema => ({
      watch => {
        wid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        uid => { type => "INTEGER" },
        watched_uid => { type => "INTEGER" },
        time  => { type => "INTEGER" },
      },
    }),
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @chatarray = split(/\s+/, $chat);
  my $watched_user = @chatarray ? $DCBUser::userlist->{lc(shift(@chatarray))} : '';

  my @return = ();
  my $message = '';

  if ($watched_user) {
    if (grep $_ eq $user->{'uid'}, watch_get_watchers($watched_user)) {
      $message = "You are already watching $watched_user->{name}.";
    }
    else {
      my %fields = (
        'uid' => $user->{uid},
        'watched_uid' => $watched_user->{uid},
        'time' => time(),
      );
      DCBDatabase::db_insert('watch', \%fields);
      $message = "You are now watching $watched_user->{name} and will receive messages whenever they log in or out.";
    }
  }
  else {
    $message = "Currently watching the following users:\n";
    my @watching = watch_get_watching($user);
    foreach my $watched (@watching) {
      my $w_user = user_load($watched);
      $message .= $w_user->{'name'} . "\n";
    }
  }

  @return = (
    {
      param    => "message",
      message  => "$message",
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

sub postlogin {
  my $command = shift;
  my $user = shift;
  return watch_action($user, 'connected');
}

sub logout {
  my $command = shift;
  my $user = shift;
  return watch_action($user, 'disconnected');
}

sub watch_action {
  my $user = shift;
  my $action = shift;
  my @return = ();
  if (watch_check_uid($user)) {
    my @uids = watch_get_watchers($user);
    foreach my $uid (@uids) {
      my $watcher = user_load($uid);
      my @usermessage = (
        {
          param    => "message",
          message  => "A user you are watching ($user->{'name'}) has $action",
          user     => $watcher->{name},
          touser   => '',
          type     => MESSAGE->{'PUBLIC_SINGLE'},
        },
      );
      push(@return, @usermessage);
    }
  }
  return @return;
}

sub watch_check_uid {
  my $user = shift;
  my @fields = ('watched_uid');
  my %where = ('watched_uid' => $user->{uid});
  my $watchcheckh = DCBDatabase::db_select('watch', 1, \%where, \(), 1);
  if ($watchcheckh->fetchrow_array()) {
    return 1;
  }
  return 0;
}

sub watch_get_watchers {
  my $user = shift;
  my @fields = ('uid', 'watched_uid');
  my %where = ('watched_uid' => $user->{uid});
  my $watchh = DCBDatabase::db_select('watch', \@fields, \%where);
  my @return = ();
  while (my $watch = $watchh->fetchrow_hashref()) {
    push(@return, $watch->{uid});
  }
  return @return;
}

sub watch_get_watching {
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
