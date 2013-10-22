package tell;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;
use DCBUser;
use DCBDatabase;

sub schema {
  my %schema = (
    schema => ({
      tell => {
        tid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        from_uid => { type => "INTEGER" },
        to_uid => { type => "VARCHAR(35)" },
        time  => { type => "INT" },
        message  => { type => "BLOB" },
      },
    }),
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();
  my $message = '';

  # TODO could instantiate a global to store (in hook_init) who has it in and make it even faster
  my @chatarray = split(/\s+/, $chat);
  my $to_user_name = shift(@chatarray);
  my $tell_message = join(' ', @chatarray);

  if ($to_user_name) {
    my $to_user = user_load_by_name($to_user_name);
    if ($to_user->{uid}) {
      my %fields = (
        'from_uid' => $user->{uid},
        'to_uid' => $to_user->{uid},
        'time' => time(),
        'message' => $tell_message,
      );
      DCBDatabase::db_insert('tell', \%fields);
      my $action = ($to_user->{connect_time} - $to_user->{disconnect_time} < 0) ? 'log on' : 'speak in chat';
      $message = "Message from $user->{name} to $to_user->{name} saved and will be delivered next time they $action";
    }
    else {
      $message = "$to_user_name is not a user - no message saved."
    }
  }
  else {
    $message = "No user specified."
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

sub line {
  my $command = shift;
  my $user = shift;
  return tell_handler($user);
}

sub postlogin {
  my $command = shift;
  my $user = shift;
  return tell_handler($user);
}

sub tell_handler {
  my $user = shift;
  if (tell_check_tells($user)) {
    my $tells = tell_get_tells($user);
    my @return = (
      {
        param    => "message",
        message  => "$tells",
        user     => $user->{name},
        touser   => '',
        type     => MESSAGE->{'PUBLIC_SINGLE'},
      },
      {
        param    => "message",
        message  => "$tells",
        user     => $user->{name},
        touser   => '',
        type     => MESSAGE->{'BOT_PM'},
      },
    );
    return @return;
  }
  return;
}

sub tell_check_tells {
  my $user = shift;
  # TODO Check global for uid || check db
  my @fields = ('to_uid');
  my %where = ('to_uid' => $user->{uid});
  my $tellcheckh = DCBDatabase::db_select('tell', 1, \%where, \(), 1);
  if ($tellcheckh->fetchrow_array()) {
    return 1;
  }
  return 0;
}

sub tell_get_tells {
  my $user = shift;
  my @fields = ('tid', 'from_uid', 'time', 'message');
  my %where = ('to_uid' => $user->{uid});
  my $order = {-asc => 'tid'};
  my $tellh = DCBDatabase::db_select('tell', \@fields, \%where, $order);
  my $return = "$user->{name} you have received the following messages:\n";
  while (my $tell = $tellh->fetchrow_hashref()) {
    # Consider using a user_cache
    my $timestamp = DCBCommon::common_timestamp_time($tell->{time});
    my $from_user = user_load($tell->{from_uid});
    $return .= "At $timestamp, $from_user->{name} said: $tell->{message}\n";
    my %deletetid = ('tid' => $tell->{tid});
    DCBDatabase::db_delete('tell', \%deletetid);
  }
  return $return;
}

1;
