package ranks;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBDatabase;
use DCBUser;
use POSIX qw(floor);

sub schema {
  my %schema = (
    schema => ({
      ranks => {
        rid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        uid        => { type => "INTEGER" },
        xp         => { type => "INT" },
        level      => { type => "INT" },
        total_xp   => { type => "INT" },
        chat_xp    => { type => "INT" },
        share_xp   => { type => "INT" },
        social_xp  => { type => "INT" },
        trivia_xp  => { type => "INT" },
        loyalty_xp => { type => "INT" },
        last_chat  => { type => "INT" },
        streak_days => { type => "INT" },
        last_daily  => { type => "INT" },
      },
    }),
    config => {
      ranks_xp_per_chat       => 1,
      ranks_xp_chat_cooldown  => 5,
      ranks_xp_per_login      => 10,
      ranks_xp_daily_bonus    => 25,
      ranks_xp_streak_bonus   => 5,
      ranks_xp_karma_give     => 3,
      ranks_xp_karma_recv     => 5,
      ranks_xp_trivia_correct => 10,
      ranks_xp_trivia_win     => 50,
      ranks_xp_share_gb       => 2,
      ranks_xp_session_hour   => 5,
      ranks_xp_achievement    => 20,
      ranks_xp_penalty_spam   => -10,
    },
  );
  return \%schema;
}

# --- Rank Titles (level => title) ---

sub rank_titles {
  return [
    { level => 0,  title => 'Newcomer',         icon => '.' },
    { level => 3,  title => 'Lurker',            icon => '-' },
    { level => 5,  title => 'Chatter',           icon => '~' },
    { level => 8,  title => 'Regular',           icon => '=' },
    { level => 10, title => 'Contributor',       icon => '+' },
    { level => 13, title => 'Hub Rat',           icon => '*' },
    { level => 15, title => 'Socialite',         icon => '**' },
    { level => 18, title => 'Veteran',           icon => '***' },
    { level => 20, title => 'Elite',             icon => '****' },
    { level => 25, title => 'Hub Legend',        icon => '*****' },
    { level => 30, title => 'Grand Master',      icon => '+++' },
    { level => 35, title => 'Mythical',          icon => '>>>' },
    { level => 40, title => 'Transcendent',      icon => '<<<>>>' },
    { level => 50, title => 'Hub God',           icon => '[GOD]' },
  ];
}

sub rank_get_title {
  my ($level) = @_;
  my $titles = rank_titles();
  my $title = $titles->[0];
  foreach my $t (@{$titles}) {
    last if $t->{level} > $level;
    $title = $t;
  }
  return $title;
}

# XP required for a given level: 100 * level^1.5
sub xp_for_level {
  my ($level) = @_;
  return 0 if $level <= 0;
  return floor(100 * ($level ** 1.5));
}

sub xp_to_next_level {
  my ($level, $xp) = @_;
  my $needed = xp_for_level($level + 1);
  my $current_base = xp_for_level($level);
  my $progress = $xp - $current_base;
  my $required = $needed - $current_base;
  return ($progress, $required);
}

# --- Hooks ---

sub init {
  $DCBCommon::COMMON->{ranks} = {
    cache  => {},
    dirty  => {},
    last_flush => time(),
  };

  # Load all rank data into memory
  my @fields = ('*');
  my $sth = DCBDatabase::db_select('ranks', \@fields);
  while (my $row = $sth->fetchrow_hashref()) {
    $DCBCommon::COMMON->{ranks}->{cache}->{$row->{uid}} = $row;
  }
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  my @args = split(/\s+/, $chat);
  my $action = shift(@args) || '';
  $action = lc($action);

  # Handle alias commands
  my $cmd_name = $command->{name};
  if ($cmd_name eq 'leaderboard' || $action eq 'top' || $action eq 'leaderboard') {
    return ranks_leaderboard($user);
  }
  elsif ($action eq 'stats' || $action eq 'breakdown') {
    my $target_name = shift(@args) || '';
    return ranks_stats($user, $target_name);
  }
  elsif ($action eq 'titles' || $action eq 'levels') {
    return ranks_show_titles($user);
  }
  elsif ($action eq 'help') {
    return ranks_help($user);
  }
  elsif ($action) {
    # Look up a user
    return ranks_show_user($user, $action);
  }
  else {
    return ranks_show_user($user, '');
  }
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  return @return unless $user->{uid} && $user->{uid} > 1;
  return @return unless $DCBCommon::COMMON->{ranks};

  my $uid = $user->{uid};
  my $rank = ranks_ensure_user($uid);

  # Chat XP with cooldown
  my $cooldown = DCBSettings::config_get('ranks_xp_chat_cooldown') || 5;
  my $now = time();
  if (!$rank->{last_chat} || ($now - $rank->{last_chat}) >= $cooldown) {
    my $chat_xp = DCBSettings::config_get('ranks_xp_per_chat') || 1;

    # Bonus for longer messages (encourage substance)
    my $len = length($chat || '');
    if ($len > 50)  { $chat_xp += 1; }
    if ($len > 150) { $chat_xp += 1; }

    push(@return, ranks_add_xp($user, $chat_xp, 'chat_xp'));
    $rank->{last_chat} = $now;
    $DCBCommon::COMMON->{ranks}->{dirty}->{$uid} = 1;
  }

  # Karma giving XP
  if ($chat =~ /(\S+)\+\+/ || $chat =~ /(\w+)--/) {
    my $karma_xp = DCBSettings::config_get('ranks_xp_karma_give') || 3;
    push(@return, ranks_add_xp($user, $karma_xp, 'social_xp'));
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub postlogin {
  my $command = shift;
  my $user = shift;
  my @return = ();

  return @return unless $user->{uid} && $user->{uid} > 1;
  return @return unless $DCBCommon::COMMON->{ranks};

  my $uid = $user->{uid};
  my $rank = ranks_ensure_user($uid);

  # Login XP
  my $login_xp = DCBSettings::config_get('ranks_xp_per_login') || 10;
  push(@return, ranks_add_xp($user, $login_xp, 'loyalty_xp'));

  # Daily login bonus with streak
  my $today = floor(time() / 86400);
  my $last_daily = $rank->{last_daily} || 0;
  my $last_day = floor($last_daily / 86400) if $last_daily;

  if (!$last_daily || $today > $last_day) {
    my $daily_xp = DCBSettings::config_get('ranks_xp_daily_bonus') || 25;
    push(@return, ranks_add_xp($user, $daily_xp, 'loyalty_xp'));

    # Streak check: was the last daily yesterday?
    if ($last_daily && $today - $last_day == 1) {
      $rank->{streak_days} = ($rank->{streak_days} || 0) + 1;
      my $streak_bonus = DCBSettings::config_get('ranks_xp_streak_bonus') || 5;
      my $streak_xp = $streak_bonus * ($rank->{streak_days} > 10 ? 10 : $rank->{streak_days});
      push(@return, ranks_add_xp($user, $streak_xp, 'loyalty_xp'));

      if ($rank->{streak_days} % 7 == 0) {
        push(@return, {
          param   => "message",
          message => "*** $user->{name} is on a $rank->{streak_days}-day login streak! ***",
          user    => '',
          touser  => '',
          type    => MESSAGE->{'PUBLIC_ALL'},
        });
      }
    }
    else {
      $rank->{streak_days} = 1;
    }

    $rank->{last_daily} = time();
    $DCBCommon::COMMON->{ranks}->{dirty}->{$uid} = 1;
  }

  # Share XP (per GB shared)
  if ($user->{connect_share}) {
    my $gb = floor($user->{connect_share} / 1073741824);
    my $share_per_gb = DCBSettings::config_get('ranks_xp_share_gb') || 2;
    my $share_xp = $gb * $share_per_gb;
    if ($share_xp > 0 && $share_xp <= 500) {
      push(@return, ranks_add_xp($user, $share_xp, 'share_xp'));
    }
  }

  # Show rank card on login
  $rank = $DCBCommon::COMMON->{ranks}->{cache}->{$uid};
  my $title = rank_get_title($rank->{level} || 0);
  my ($progress, $required) = xp_to_next_level($rank->{level} || 0, $rank->{total_xp} || 0);
  my $bar = ranks_progress_bar($progress, $required);

  push(@return, {
    param   => "message",
    message => "Welcome back, $user->{name}! You are Level $rank->{level} ($title->{title}) $bar",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub logout {
  my $command = shift;
  my $user = shift;
  my @return = ();

  return @return unless $user->{uid} && $user->{uid} > 1;
  return @return unless $DCBCommon::COMMON->{ranks};

  # Session duration XP
  if ($user->{connect_time}) {
    my $hours = floor((time() - $user->{connect_time}) / 3600);
    if ($hours > 0) {
      my $session_xp_rate = DCBSettings::config_get('ranks_xp_session_hour') || 5;
      my $session_xp = $hours * $session_xp_rate;
      $session_xp = 50 if $session_xp > 50;  # Cap at 50 XP per session
      push(@return, ranks_add_xp($user, $session_xp, 'loyalty_xp'));
    }
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub timer {
  return unless $DCBCommon::COMMON->{ranks};

  # Flush dirty data to DB every 60 seconds
  if (time() - ($DCBCommon::COMMON->{ranks}->{last_flush} || 0) >= 60) {
    ranks_flush();
    $DCBCommon::COMMON->{ranks}->{last_flush} = time();
  }
}

# --- Core XP Logic ---

sub ranks_ensure_user {
  my ($uid) = @_;
  if (!$DCBCommon::COMMON->{ranks}->{cache}->{$uid}) {
    $DCBCommon::COMMON->{ranks}->{cache}->{$uid} = {
      uid        => $uid,
      xp         => 0,
      level      => 0,
      total_xp   => 0,
      chat_xp    => 0,
      share_xp   => 0,
      social_xp  => 0,
      trivia_xp  => 0,
      loyalty_xp => 0,
      last_chat  => 0,
      streak_days => 0,
      last_daily  => 0,
      _new       => 1,
    };
  }
  return $DCBCommon::COMMON->{ranks}->{cache}->{$uid};
}

sub ranks_add_xp {
  my ($user, $amount, $category) = @_;
  my @return = ();
  my $uid = $user->{uid};
  my $rank = ranks_ensure_user($uid);

  $rank->{xp}       = ($rank->{xp} || 0) + $amount;
  $rank->{total_xp} = ($rank->{total_xp} || 0) + $amount;
  $rank->{$category} = ($rank->{$category} || 0) + $amount if $category;
  $DCBCommon::COMMON->{ranks}->{dirty}->{$uid} = 1;

  # Check for level up
  my $old_level = $rank->{level} || 0;
  while ($rank->{total_xp} >= xp_for_level($old_level + 1)) {
    $old_level++;
  }

  if ($old_level > ($rank->{level} || 0)) {
    my $new_title = rank_get_title($old_level);
    my $old_title = rank_get_title($rank->{level} || 0);
    $rank->{level} = $old_level;

    my $level_msg = "*** LEVEL UP! $user->{name} reached Level $old_level";
    if ($new_title->{title} ne $old_title->{title}) {
      $level_msg .= " - New title: $new_title->{icon} $new_title->{title}";
    }
    $level_msg .= " ***";

    push(@return, {
      param   => "message",
      message => $level_msg,
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });
  }

  return @return;
}

# --- Display ---

sub ranks_show_user {
  my ($viewer, $target_name) = @_;

  my $target = $viewer;
  if ($target_name) {
    $target = DCBUser::user_load_by_name($target_name);
    if (!$target || !$target->{uid}) {
      return ({
        param   => "message",
        message => "User '$target_name' not found.",
        user    => $viewer->{name},
        touser  => '',
        type    => MESSAGE->{'PUBLIC_SINGLE'},
      });
    }
  }

  my $rank = $DCBCommon::COMMON->{ranks}->{cache}->{$target->{uid}};
  if (!$rank) {
    return ({
      param   => "message",
      message => "$target->{name} has no rank data yet.",
      user    => $viewer->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $title = rank_get_title($rank->{level} || 0);
  my ($progress, $required) = xp_to_next_level($rank->{level} || 0, $rank->{total_xp} || 0);
  my $bar = ranks_progress_bar($progress, $required);

  my $message = "*** Rank Card: $target->{name} ***\n";
  $message .= "Title: $title->{icon} $title->{title}\n";
  $message .= "Level: $rank->{level} $bar\n";
  $message .= "Total XP: $rank->{total_xp}\n";
  $message .= "To next level: " . ($required - $progress) . " XP\n";
  if ($rank->{streak_days} && $rank->{streak_days} > 1) {
    $message .= "Login streak: $rank->{streak_days} days\n";
  }

  return ({
    param   => "message",
    message => $message,
    user    => $viewer->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub ranks_stats {
  my ($viewer, $target_name) = @_;

  my $target = $viewer;
  if ($target_name) {
    $target = DCBUser::user_load_by_name($target_name);
    if (!$target || !$target->{uid}) {
      return ({
        param   => "message",
        message => "User '$target_name' not found.",
        user    => $viewer->{name},
        touser  => '',
        type    => MESSAGE->{'PUBLIC_SINGLE'},
      });
    }
  }

  my $rank = $DCBCommon::COMMON->{ranks}->{cache}->{$target->{uid}};
  if (!$rank) {
    return ({
      param   => "message",
      message => "$target->{name} has no rank data yet.",
      user    => $viewer->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $total = $rank->{total_xp} || 1;
  my $message = "*** XP Breakdown: $target->{name} ***\n";
  $message .= "Chat XP:    " . ($rank->{chat_xp} || 0) . " (" . floor((($rank->{chat_xp} || 0) / $total) * 100) . "%)\n";
  $message .= "Social XP:  " . ($rank->{social_xp} || 0) . " (" . floor((($rank->{social_xp} || 0) / $total) * 100) . "%)\n";
  $message .= "Loyalty XP: " . ($rank->{loyalty_xp} || 0) . " (" . floor((($rank->{loyalty_xp} || 0) / $total) * 100) . "%)\n";
  $message .= "Share XP:   " . ($rank->{share_xp} || 0) . " (" . floor((($rank->{share_xp} || 0) / $total) * 100) . "%)\n";
  $message .= "Trivia XP:  " . ($rank->{trivia_xp} || 0) . " (" . floor((($rank->{trivia_xp} || 0) / $total) * 100) . "%)\n";
  $message .= "Total: $rank->{total_xp} XP\n";

  return ({
    param   => "message",
    message => $message,
    user    => $viewer->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub ranks_leaderboard {
  my ($user) = @_;

  # Sort cached users by total_xp
  my @sorted = sort { ($DCBCommon::COMMON->{ranks}->{cache}->{$b}->{total_xp} || 0) <=> ($DCBCommon::COMMON->{ranks}->{cache}->{$a}->{total_xp} || 0) } keys %{$DCBCommon::COMMON->{ranks}->{cache}};

  my $message = "*** HUB LEADERBOARD (Top 15) ***\n";
  my $rank_num = 1;
  my $found = 0;
  foreach my $uid (@sorted) {
    last if $rank_num > 15;
    my $r = $DCBCommon::COMMON->{ranks}->{cache}->{$uid};
    next unless $r->{total_xp} && $r->{total_xp} > 0;
    $found = 1;
    my $u = DCBUser::user_load($uid);
    my $name = $u ? $u->{name} : "Unknown";
    my $title = rank_get_title($r->{level} || 0);
    my $medal = $rank_num == 1 ? '[1st]' : $rank_num == 2 ? '[2nd]' : $rank_num == 3 ? '[3rd]' : "#$rank_num";
    $message .= "$medal $title->{icon} $name - Level $r->{level} ($title->{title}) - $r->{total_xp} XP\n";
    $rank_num++;
  }

  if (!$found) {
    $message .= "No ranked users yet! Start chatting to earn XP.\n";
  }

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub ranks_show_titles {
  my ($user) = @_;
  my $titles = rank_titles();

  my $message = "*** RANK TITLES ***\n";
  foreach my $t (@{$titles}) {
    my $xp_needed = xp_for_level($t->{level});
    $message .= "Level $t->{level}+ $t->{icon} $t->{title} ($xp_needed XP)\n";
  }
  $message .= "\nXP formula: each level requires 100 * level^1.5 total XP";

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub ranks_help {
  my ($user) = @_;
  my $message = "*** RANK SYSTEM ***\n";
  $message .= "-rank - View your rank card\n";
  $message .= "-rank [user] - View someone's rank\n";
  $message .= "-rank stats [user] - XP breakdown by category\n";
  $message .= "-rank titles - See all rank titles and levels\n";
  $message .= "-leaderboard - Top 15 users\n\n";
  $message .= "*** EARNING XP ***\n";
  $message .= "Chat messages: 1-3 XP (longer = more)\n";
  $message .= "Daily login: 25 XP + streak bonus\n";
  $message .= "Login streak: +5 XP per day (up to 50)\n";
  $message .= "Give karma: 3 XP\n";
  $message .= "File sharing: 2 XP per GB shared\n";
  $message .= "Session time: 5 XP per hour (max 50)\n";
  $message .= "Trivia correct: 10 XP\n";
  $message .= "Win trivia round: 50 XP\n";

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub ranks_progress_bar {
  my ($progress, $required) = @_;
  $required = 1 if !$required || $required <= 0;
  my $pct = floor(($progress / $required) * 100);
  $pct = 100 if $pct > 100;
  my $filled = floor($pct / 5);
  my $empty = 20 - $filled;
  return '[' . ('|' x $filled) . ('.' x $empty) . "] ${pct}%";
}

# --- Persistence ---

sub ranks_flush {
  my $dirty = $DCBCommon::COMMON->{ranks}->{dirty};
  return unless $dirty && keys %{$dirty};

  foreach my $uid (keys %{$dirty}) {
    my $rank = $DCBCommon::COMMON->{ranks}->{cache}->{$uid};
    next unless $rank;

    my %fields = (
      'xp'          => $rank->{xp} || 0,
      'level'       => $rank->{level} || 0,
      'total_xp'    => $rank->{total_xp} || 0,
      'chat_xp'     => $rank->{chat_xp} || 0,
      'share_xp'    => $rank->{share_xp} || 0,
      'social_xp'   => $rank->{social_xp} || 0,
      'trivia_xp'   => $rank->{trivia_xp} || 0,
      'loyalty_xp'  => $rank->{loyalty_xp} || 0,
      'last_chat'   => $rank->{last_chat} || 0,
      'streak_days' => $rank->{streak_days} || 0,
      'last_daily'  => $rank->{last_daily} || 0,
    );

    if ($rank->{_new}) {
      $fields{'uid'} = $uid;
      DCBDatabase::db_insert('ranks', \%fields);
      delete $rank->{_new};
    }
    else {
      my %where = ('uid' => $uid);
      DCBDatabase::db_update('ranks', \%fields, \%where);
    }
  }

  $DCBCommon::COMMON->{ranks}->{dirty} = {};
}

1;
