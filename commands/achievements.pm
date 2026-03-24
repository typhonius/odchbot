package achievements;

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
      achievements => {
        aid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        uid             => { type => "INTEGER" },
        achievement_id  => { type => "VARCHAR(50)" },
        unlocked_time   => { type => "INT" },
      },
      achievement_progress => {
        apid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        uid             => { type => "INTEGER" },
        achievement_id  => { type => "VARCHAR(50)" },
        progress        => { type => "INT" },
      },
    }),
  );
  return \%schema;
}

# --- Achievement Definitions ---

sub achievement_definitions {
  return {
    # Chat Milestones
    first_words   => { name => 'First Words',   desc => 'Send your first chat message',           category => 'Chat',    threshold => 1,     icon => '[*]' },
    chatterbox    => { name => 'Chatterbox',     desc => 'Send 100 chat messages',                 category => 'Chat',    threshold => 100,   icon => '[**]' },
    motor_mouth   => { name => 'Motor Mouth',    desc => 'Send 1,000 chat messages',               category => 'Chat',    threshold => 1000,  icon => '[***]' },
    novelist      => { name => 'Novelist',       desc => 'Send 5,000 chat messages',               category => 'Chat',    threshold => 5000,  icon => '[****]' },
    chat_legend   => { name => 'Chat Legend',     desc => 'Send 10,000 chat messages',              category => 'Chat',    threshold => 10000, icon => '[*****]' },
    night_owl     => { name => 'Night Owl',      desc => 'Chat between midnight and 5am',          category => 'Chat',    threshold => 1,     icon => '[OWL]' },
    early_bird    => { name => 'Early Bird',     desc => 'Chat between 5am and 7am',               category => 'Chat',    threshold => 1,     icon => '[BIRD]' },

    # Social
    karma_giver   => { name => 'Karma Giver',   desc => 'Give karma 10 times',                    category => 'Social',  threshold => 10,    icon => '[+]' },
    karma_magnet  => { name => 'Karma Magnet',   desc => 'Receive karma 50 times',                 category => 'Social',  threshold => 50,    icon => '[++]' },
    helper        => { name => 'Helper',         desc => 'Use the help command 5 times',           category => 'Social',  threshold => 5,     icon => '[?]' },
    searcher      => { name => 'Searcher',       desc => 'Perform 10 searches',                    category => 'Social',  threshold => 10,    icon => '[S]' },
    storyteller   => { name => 'Storyteller',    desc => 'Add 5 quotes to the database',           category => 'Social',  threshold => 5,     icon => '[Q]' },

    # Hub Loyalty
    welcome       => { name => 'Welcome',        desc => 'Connect to the hub for the first time',  category => 'Loyalty', threshold => 1,     icon => '[W]' },
    regular       => { name => 'Regular',        desc => 'Connect to the hub 10 times',            category => 'Loyalty', threshold => 10,    icon => '[R]' },
    veteran       => { name => 'Veteran',        desc => 'Connect to the hub 100 times',           category => 'Loyalty', threshold => 100,   icon => '[V]' },
    week_one      => { name => 'Week One',       desc => 'Be a member for 7 days',                 category => 'Loyalty', threshold => 7,     icon => '[7d]' },
    old_timer     => { name => 'Old Timer',      desc => 'Be a member for 30 days',                category => 'Loyalty', threshold => 30,    icon => '[30d]' },
    founding      => { name => 'Founding Member', desc => 'Be a member for 365 days',              category => 'Loyalty', threshold => 365,   icon => '[365d]' },
    data_hoarder  => { name => 'Data Hoarder',  desc => 'Share more than 100GB',                  category => 'Loyalty', threshold => 1,     icon => '[HD]' },
    marathon      => { name => 'Marathon',       desc => 'Stay connected for 8 hours straight',    category => 'Loyalty', threshold => 1,     icon => '[M]' },

    # Fun & Games
    trivia_novice => { name => 'Trivia Novice',  desc => 'Answer 10 trivia questions correctly',   category => 'Games',   threshold => 10,    icon => '[T]' },
    trivia_master => { name => 'Trivia Master',  desc => 'Answer 100 trivia questions correctly',  category => 'Games',   threshold => 100,   icon => '[TM]' },
    dice_roller   => { name => 'Dice Roller',    desc => 'Roll dice 50 times',                     category => 'Games',   threshold => 50,    icon => '[D]' },
  };
}

# --- Hooks ---

sub init {
  # Initialize in-memory cache
  $DCBCommon::COMMON->{achievements} = {
    unlocked => {},
    progress => {},
    dirty    => {},
    last_flush => time(),
  };

  # Load all unlocked achievements into memory
  my @fields = ('uid', 'achievement_id');
  my $sth = DCBDatabase::db_select('achievements', \@fields);
  while (my $row = $sth->fetchrow_hashref()) {
    $DCBCommon::COMMON->{achievements}->{unlocked}->{$row->{uid}}->{$row->{achievement_id}} = 1;
  }

  # Load progress into memory
  my @pfields = ('uid', 'achievement_id', 'progress');
  my $psth = DCBDatabase::db_select('achievement_progress', \@pfields);
  while (my $row = $psth->fetchrow_hashref()) {
    $DCBCommon::COMMON->{achievements}->{progress}->{$row->{uid}}->{$row->{achievement_id}} = $row->{progress};
  }
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  my @args = split(/\s+/, $chat);
  my $target_name = shift(@args) || '';

  if ($target_name eq 'list' || $target_name eq 'all') {
    return achievements_list_all($user);
  }

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

  return achievements_show($user, $target);
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  # Don't track bot messages
  return @return unless $user->{uid} && $user->{uid} > 1;
  return @return unless $DCBCommon::COMMON->{achievements};

  my $uid = $user->{uid};

  # Increment chat count
  my $chat_count = achievement_increment($uid, 'chat_messages');
  # Check chat milestones
  push(@return, achievement_check_unlock($user, 'first_words', $chat_count));
  push(@return, achievement_check_unlock($user, 'chatterbox', $chat_count));
  push(@return, achievement_check_unlock($user, 'motor_mouth', $chat_count));
  push(@return, achievement_check_unlock($user, 'novelist', $chat_count));
  push(@return, achievement_check_unlock($user, 'chat_legend', $chat_count));

  # Time-of-day achievements
  my $hour = (localtime(time()))[2];
  if ($hour >= 0 && $hour < 5) {
    push(@return, achievement_check_unlock($user, 'night_owl', 1));
  }
  elsif ($hour >= 5 && $hour < 7) {
    push(@return, achievement_check_unlock($user, 'early_bird', 1));
  }

  # Track karma giving (detect ++ or -- in chat)
  if ($chat =~ /\S+\+\+/ || $chat =~ /\w+--/) {
    my $karma_given = achievement_increment($uid, 'karma_given');
    push(@return, achievement_check_unlock($user, 'karma_giver', $karma_given));
  }

  # Track karma receiving (detect username++ where username matches this user)
  my $name_lc = lc($user->{name});
  if ($chat =~ /(\S+)\+\+/) {
    my $target = lc($1);
    # We can't easily detect receiving here since $user is the sender
    # This will be handled by matching the target name in the karma line
  }

  # Filter out return values that are empty
  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub postlogin {
  my $command = shift;
  my $user = shift;
  my @return = ();

  return @return unless $user->{uid} && $user->{uid} > 1;
  return @return unless $DCBCommon::COMMON->{achievements};

  my $uid = $user->{uid};

  # Connection count
  my $connections = achievement_increment($uid, 'connections');
  push(@return, achievement_check_unlock($user, 'welcome', $connections));
  push(@return, achievement_check_unlock($user, 'regular', $connections));
  push(@return, achievement_check_unlock($user, 'veteran', $connections));

  # Membership duration (check join_time)
  if ($user->{join_time}) {
    my $days = int((time() - $user->{join_time}) / 86400);
    if ($days >= 7) {
      push(@return, achievement_check_unlock($user, 'week_one', 7));
    }
    if ($days >= 30) {
      push(@return, achievement_check_unlock($user, 'old_timer', 30));
    }
    if ($days >= 365) {
      push(@return, achievement_check_unlock($user, 'founding', 365));
    }
  }

  # Share size check (100GB = 107374182400 bytes)
  if ($user->{connect_share} && $user->{connect_share} > 107374182400) {
    push(@return, achievement_check_unlock($user, 'data_hoarder', 1));
  }

  # Check trivia scores for trivia achievements
  push(@return, achievement_check_trivia($user));

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub logout {
  my $command = shift;
  my $user = shift;
  my @return = ();

  return @return unless $user->{uid} && $user->{uid} > 1;
  return @return unless $DCBCommon::COMMON->{achievements};

  # Check session duration for marathon (8 hours = 28800 seconds)
  if ($user->{connect_time}) {
    my $session_length = time() - $user->{connect_time};
    if ($session_length >= 28800) {
      push(@return, achievement_check_unlock($user, 'marathon', 1));
    }
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub timer {
  return unless $DCBCommon::COMMON->{achievements};

  my @return = ();

  # Check marathon for online users (every timer tick)
  foreach my $name (keys %{$DCBUser::userlist}) {
    my $u = $DCBUser::userlist->{$name};
    next unless $u->{uid} && $u->{uid} > 1;
    next unless $u->{connect_time};
    next if $u->{disconnect_time} && $u->{disconnect_time} > $u->{connect_time};

    my $session = time() - $u->{connect_time};
    if ($session >= 28800) {
      push(@return, achievement_check_unlock($u, 'marathon', 1));
    }
  }

  # Flush dirty progress to DB every 60 seconds
  if (time() - ($DCBCommon::COMMON->{achievements}->{last_flush} || 0) >= 60) {
    achievement_flush_progress();
    $DCBCommon::COMMON->{achievements}->{last_flush} = time();
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

# --- Core Logic ---

sub achievement_increment {
  my ($uid, $counter_id) = @_;
  $DCBCommon::COMMON->{achievements}->{progress}->{$uid}->{$counter_id} =
    ($DCBCommon::COMMON->{achievements}->{progress}->{$uid}->{$counter_id} || 0) + 1;
  $DCBCommon::COMMON->{achievements}->{dirty}->{$uid}->{$counter_id} = 1;
  return $DCBCommon::COMMON->{achievements}->{progress}->{$uid}->{$counter_id};
}

sub achievement_check_unlock {
  my ($user, $achievement_id, $current_value) = @_;
  my $uid = $user->{uid};

  # Already unlocked?
  return undef if $DCBCommon::COMMON->{achievements}->{unlocked}->{$uid}->{$achievement_id};

  my $defs = achievement_definitions();
  my $def = $defs->{$achievement_id};
  return undef unless $def;

  if ($current_value >= $def->{threshold}) {
    # Unlock it!
    $DCBCommon::COMMON->{achievements}->{unlocked}->{$uid}->{$achievement_id} = 1;

    my %fields = (
      'uid'            => $uid,
      'achievement_id' => $achievement_id,
      'unlocked_time'  => time(),
    );
    DCBDatabase::db_insert('achievements', \%fields);

    return {
      param   => "message",
      message => "*** ACHIEVEMENT UNLOCKED! $user->{name} earned $def->{icon} $def->{name}: $def->{desc} ***",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    };
  }

  return undef;
}

sub achievement_check_trivia {
  my ($user) = @_;
  my @return = ();
  my $uid = $user->{uid};

  # Check if trivia_scores table has data for this user
  eval {
    my @fields = ('correct');
    my %where = ('uid' => $uid);
    my $sth = DCBDatabase::db_select('trivia_scores', \@fields, \%where);
    my $row = $sth->fetchrow_hashref();
    if ($row && $row->{correct}) {
      push(@return, achievement_check_unlock($user, 'trivia_novice', $row->{correct}));
      push(@return, achievement_check_unlock($user, 'trivia_master', $row->{correct}));
    }
  };
  # Silently ignore if trivia_scores table doesn't exist yet

  return @return;
}

sub achievement_flush_progress {
  my $dirty = $DCBCommon::COMMON->{achievements}->{dirty};
  return unless $dirty;

  foreach my $uid (keys %{$dirty}) {
    foreach my $counter_id (keys %{$dirty->{$uid}}) {
      my $value = $DCBCommon::COMMON->{achievements}->{progress}->{$uid}->{$counter_id} || 0;

      # Check if row exists
      my @fields = ('progress');
      my %where = ('uid' => $uid, 'achievement_id' => $counter_id);
      my $sth = DCBDatabase::db_select('achievement_progress', \@fields, \%where);
      my $row = $sth->fetchrow_hashref();

      if ($row) {
        my %update = ('progress' => $value);
        DCBDatabase::db_update('achievement_progress', \%update, \%where);
      }
      else {
        my %insert = (
          'uid'            => $uid,
          'achievement_id' => $counter_id,
          'progress'       => $value,
        );
        DCBDatabase::db_insert('achievement_progress', \%insert);
      }
    }
  }

  $DCBCommon::COMMON->{achievements}->{dirty} = {};
}

# --- Display ---

sub achievements_show {
  my ($viewer, $target) = @_;
  my $uid = $target->{uid};
  my $defs = achievement_definitions();
  my $unlocked = $DCBCommon::COMMON->{achievements}->{unlocked}->{$uid} || {};
  my $progress = $DCBCommon::COMMON->{achievements}->{progress}->{$uid} || {};

  my $message = "*** Achievements for $target->{name} ***\n\n";

  # Group by category
  my %by_cat = ();
  foreach my $id (keys %{$defs}) {
    push(@{$by_cat{$defs->{$id}->{category}}}, $id);
  }

  my $total_unlocked = 0;
  my $total = 0;

  foreach my $cat (sort keys %by_cat) {
    $message .= "=== $cat ===\n";
    foreach my $id (sort @{$by_cat{$cat}}) {
      my $def = $defs->{$id};
      $total++;
      if ($unlocked->{$id}) {
        $total_unlocked++;
        $message .= "  $def->{icon} $def->{name} - $def->{desc} [UNLOCKED]\n";
      }
      else {
        # Show progress for trackable achievements
        my $prog = achievement_get_display_progress($uid, $id, $def);
        $message .= "  [ ] $def->{name} - $def->{desc} $prog\n";
      }
    }
    $message .= "\n";
  }

  $message .= "Progress: $total_unlocked/$total achievements unlocked";

  return ({
    param   => "message",
    message => $message,
    user    => $viewer->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub achievements_list_all {
  my ($user) = @_;
  my $defs = achievement_definitions();

  my $message = "*** ALL ACHIEVEMENTS ***\n\n";
  my %by_cat = ();
  foreach my $id (keys %{$defs}) {
    push(@{$by_cat{$defs->{$id}->{category}}}, $id);
  }

  foreach my $cat (sort keys %by_cat) {
    $message .= "=== $cat ===\n";
    foreach my $id (sort @{$by_cat{$cat}}) {
      my $def = $defs->{$id};
      my $diff = $def->{threshold} > 100 ? 'HARD' : $def->{threshold} > 10 ? 'MEDIUM' : 'EASY';
      $message .= "  $def->{icon} $def->{name} - $def->{desc} [$diff]\n";
    }
    $message .= "\n";
  }

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub achievement_get_display_progress {
  my ($uid, $achievement_id, $def) = @_;

  # Map achievement IDs to their progress counter
  my %counter_map = (
    first_words   => 'chat_messages',
    chatterbox    => 'chat_messages',
    motor_mouth   => 'chat_messages',
    novelist      => 'chat_messages',
    chat_legend   => 'chat_messages',
    karma_giver   => 'karma_given',
    helper        => 'help_used',
    searcher      => 'searches',
    storyteller   => 'quotes_added',
    welcome       => 'connections',
    regular       => 'connections',
    veteran       => 'connections',
    dice_roller   => 'dice_rolls',
  );

  my $counter = $counter_map{$achievement_id};
  if ($counter) {
    my $current = $DCBCommon::COMMON->{achievements}->{progress}->{$uid}->{$counter} || 0;
    return "($current/$def->{threshold})";
  }

  return '';
}

1;
