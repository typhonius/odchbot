package duel;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBDatabase;
use DCBUser;

sub schema {
  my %schema = (
    schema => ({
      duel_records => {
        did => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        uid     => { type => "INTEGER" },
        wins    => { type => "INT" },
        losses  => { type => "INT" },
        draws   => { type => "INT" },
      },
    }),
    config => {
      duel_timeout => 60,
      duel_xp_win => 15,
      duel_xp_lose => 3,
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  my @args = split(/\s+/, $chat);
  my $action = lc($args[0] || 'help');

  if ($action eq 'record' || $action eq 'stats') {
    my $target = $args[1] || '';
    return duel_record($user, $target);
  }
  elsif ($action eq 'top' || $action eq 'leaderboard') {
    return duel_leaderboard($user);
  }
  elsif ($action eq 'help') {
    return duel_help($user);
  }
  else {
    # Treat as challenging a user
    return duel_challenge($user, $action);
  }
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  # Fast bail if no pending duels
  return @return unless $DCBCommon::COMMON->{duels} && keys %{$DCBCommon::COMMON->{duels}};
  return @return unless $user->{uid} && $user->{uid} > 1;

  my $uid = $user->{uid};
  my $answer = lc($chat);
  $answer =~ s/^\s+|\s+$//g;

  # Check if this user has a pending duel to accept/decline
  foreach my $duel_id (keys %{$DCBCommon::COMMON->{duels}}) {
    my $duel = $DCBCommon::COMMON->{duels}->{$duel_id};
    next unless $duel->{defender_uid} == $uid;
    next unless $duel->{status} eq 'pending';

    if ($answer eq 'accept' || $answer eq 'yes') {
      push(@return, duel_fight($duel_id));
      last;
    }
    elsif ($answer eq 'decline' || $answer eq 'no') {
      my $challenger = DCBUser::user_load($duel->{challenger_uid});
      my $c_name = $challenger ? $challenger->{name} : 'Unknown';
      push(@return, {
        param   => "message",
        message => "$user->{name} declined the duel with $c_name. Coward!",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
      delete $DCBCommon::COMMON->{duels}->{$duel_id};
      last;
    }
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub timer {
  return unless $DCBCommon::COMMON->{duels};
  my @return = ();

  my $timeout = DCBSettings::config_get('duel_timeout') || 60;
  foreach my $duel_id (keys %{$DCBCommon::COMMON->{duels}}) {
    my $duel = $DCBCommon::COMMON->{duels}->{$duel_id};
    next unless $duel->{status} eq 'pending';

    if (time() - $duel->{time} > $timeout) {
      my $defender = DCBUser::user_load($duel->{defender_uid});
      my $challenger = DCBUser::user_load($duel->{challenger_uid});
      my $c_name = $challenger ? $challenger->{name} : 'Unknown';
      my $d_name = $defender ? $defender->{name} : 'Unknown';
      push(@return, {
        param   => "message",
        message => "Duel between $c_name and $d_name expired. No one showed up!",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
      delete $DCBCommon::COMMON->{duels}->{$duel_id};
    }
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

# --- Game Logic ---

sub duel_challenge {
  my ($user, $target_name) = @_;

  $DCBCommon::COMMON->{duels} = {} unless $DCBCommon::COMMON->{duels};

  # Check target exists and is online
  my $target = $DCBUser::userlist->{lc($target_name)};
  if (!$target || !$target->{uid}) {
    return ({
      param   => "message",
      message => "User '$target_name' is not online.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  if ($target->{uid} == $user->{uid}) {
    return ({
      param   => "message",
      message => "You can't duel yourself!",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  # Check no existing pending duel between these two
  foreach my $duel_id (keys %{$DCBCommon::COMMON->{duels}}) {
    my $d = $DCBCommon::COMMON->{duels}->{$duel_id};
    if ($d->{status} eq 'pending' &&
        ($d->{challenger_uid} == $user->{uid} || $d->{defender_uid} == $user->{uid})) {
      return ({
        param   => "message",
        message => "You already have a pending duel!",
        user    => $user->{name},
        touser  => '',
        type    => MESSAGE->{'PUBLIC_SINGLE'},
      });
    }
  }

  my $duel_id = $user->{uid} . '_' . $target->{uid} . '_' . time();
  $DCBCommon::COMMON->{duels}->{$duel_id} = {
    challenger_uid => $user->{uid},
    defender_uid   => $target->{uid},
    time           => time(),
    status         => 'pending',
  };

  return ({
    param   => "message",
    message => "*** $user->{name} has challenged $target->{name} to a DUEL! ***\n$target->{name}: Type 'accept' or 'decline' within 60 seconds!",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub duel_fight {
  my ($duel_id) = @_;
  my @return = ();

  my $duel = $DCBCommon::COMMON->{duels}->{$duel_id};
  $duel->{status} = 'fighting';

  my $challenger = DCBUser::user_load($duel->{challenger_uid});
  my $defender = DCBUser::user_load($duel->{defender_uid});

  if (!$challenger || !$defender) {
    delete $DCBCommon::COMMON->{duels}->{$duel_id};
    return ({
      param   => "message",
      message => "Duel cancelled - a participant could not be found.",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });
  }

  # Best of 3 rounds
  my $c_wins = 0;
  my $d_wins = 0;
  my $battle_log = "*** DUEL: $challenger->{name} vs $defender->{name} ***\n";

  for my $round (1..3) {
    my $c_roll = int(rand(20)) + 1;
    my $d_roll = int(rand(20)) + 1;
    $battle_log .= "Round $round: $challenger->{name} rolled $c_roll vs $defender->{name} rolled $d_roll";

    if ($c_roll > $d_roll) {
      $c_wins++;
      $battle_log .= " - $challenger->{name} wins!\n";
    }
    elsif ($d_roll > $c_roll) {
      $d_wins++;
      $battle_log .= " - $defender->{name} wins!\n";
    }
    else {
      $battle_log .= " - TIE!\n";
    }

    # Early victory
    last if $c_wins == 2 || $d_wins == 2;
  }

  my ($winner, $loser);
  if ($c_wins > $d_wins) {
    $winner = $challenger;
    $loser = $defender;
  }
  elsif ($d_wins > $c_wins) {
    $winner = $defender;
    $loser = $challenger;
  }

  if ($winner) {
    $battle_log .= "*** WINNER: $winner->{name} ($c_wins-$d_wins) ***";
    duel_update_record($winner->{uid}, 'win');
    duel_update_record($loser->{uid}, 'loss');

    # Award rank XP
    eval {
      if ($DCBCommon::COMMON->{ranks}) {
        my $win_xp = DCBSettings::config_get('duel_xp_win') || 15;
        my $lose_xp = DCBSettings::config_get('duel_xp_lose') || 3;
        push(@return, ranks::ranks_add_xp($winner, $win_xp, 'social_xp'));
        push(@return, ranks::ranks_add_xp($loser, $lose_xp, 'social_xp'));
      }
    };
  }
  else {
    $battle_log .= "*** DRAW! Both fighters are evenly matched. ***";
    duel_update_record($challenger->{uid}, 'draw');
    duel_update_record($defender->{uid}, 'draw');
  }

  push(@return, {
    param   => "message",
    message => $battle_log,
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });

  delete $DCBCommon::COMMON->{duels}->{$duel_id};

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub duel_update_record {
  my ($uid, $result) = @_;

  my @fields = ('*');
  my %where = ('uid' => $uid);
  my $sth = DCBDatabase::db_select('duel_records', \@fields, \%where);
  my $row = $sth->fetchrow_hashref();

  if ($row) {
    my %update = ();
    if ($result eq 'win')  { $update{wins}   = ($row->{wins} || 0) + 1; }
    if ($result eq 'loss') { $update{losses} = ($row->{losses} || 0) + 1; }
    if ($result eq 'draw') { $update{draws}  = ($row->{draws} || 0) + 1; }
    DCBDatabase::db_update('duel_records', \%update, \%where);
  }
  else {
    my %insert = (
      'uid'    => $uid,
      'wins'   => $result eq 'win' ? 1 : 0,
      'losses' => $result eq 'loss' ? 1 : 0,
      'draws'  => $result eq 'draw' ? 1 : 0,
    );
    DCBDatabase::db_insert('duel_records', \%insert);
  }
}

# --- Display ---

sub duel_record {
  my ($user, $target_name) = @_;

  my $target = $user;
  if ($target_name) {
    $target = DCBUser::user_load_by_name($target_name);
    if (!$target || !$target->{uid}) {
      return ({
        param   => "message",
        message => "User '$target_name' not found.",
        user    => $user->{name},
        touser  => '',
        type    => MESSAGE->{'PUBLIC_SINGLE'},
      });
    }
  }

  my @fields = ('*');
  my %where = ('uid' => $target->{uid});
  my $sth = DCBDatabase::db_select('duel_records', \@fields, \%where);
  my $row = $sth->fetchrow_hashref();

  if ($row) {
    my $total = ($row->{wins} || 0) + ($row->{losses} || 0) + ($row->{draws} || 0);
    my $winrate = $total > 0 ? int(($row->{wins} / $total) * 100) : 0;
    return ({
      param   => "message",
      message => "*** Duel Record: $target->{name} ***\nWins: $row->{wins} | Losses: $row->{losses} | Draws: $row->{draws}\nWin Rate: ${winrate}%",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }
  else {
    return ({
      param   => "message",
      message => "$target->{name} has never dueled.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }
}

sub duel_leaderboard {
  my ($user) = @_;

  my @fields = ('uid', 'wins', 'losses', 'draws');
  my $order = {-desc => 'wins'};
  my $sth = DCBDatabase::db_select('duel_records', \@fields, {}, $order, 10);

  my $message = "*** DUEL LEADERBOARD (Top 10) ***\n";
  my $rank = 1;
  my $found = 0;
  while (my $row = $sth->fetchrow_hashref()) {
    $found = 1;
    my $u = DCBUser::user_load($row->{uid});
    my $name = $u ? $u->{name} : "Unknown";
    my $total = ($row->{wins} || 0) + ($row->{losses} || 0);
    my $winrate = $total > 0 ? int(($row->{wins} / $total) * 100) : 0;
    $message .= "#$rank $name - $row->{wins}W/$row->{losses}L/$row->{draws}D (${winrate}%)\n";
    $rank++;
  }

  if (!$found) {
    $message .= "No duels yet! Use -duel <username> to challenge someone.";
  }

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub duel_help {
  my ($user) = @_;
  return ({
    param   => "message",
    message => "*** DUEL COMMANDS ***\n-duel <username> - Challenge someone to a duel\n-duel record [user] - View duel record\n-duel top - Duel leaderboard\n\nDuels are best-of-3 d20 rolls. Winner gets XP!",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

1;
