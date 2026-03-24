package trivia;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBDatabase;
use DCBUser;
use List::Util qw(shuffle);

sub schema {
  my %schema = (
    schema => ({
      trivia_scores => {
        tsid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        uid       => { type => "INTEGER" },
        correct   => { type => "INT" },
        wrong     => { type => "INT" },
        streak_best => { type => "INT" },
        points    => { type => "INT" },
      },
    }),
    config => {
      trivia_timeout        => 30,
      trivia_default_rounds => 10,
      trivia_streak_bonus   => 2,
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
  my $action = shift(@args) || 'help';
  $action = lc($action);

  if ($action eq 'start') {
    @return = trivia_start($user, @args);
  }
  elsif ($action eq 'stop') {
    @return = trivia_stop($user);
  }
  elsif ($action eq 'scores' || $action eq 'leaderboard') {
    @return = trivia_leaderboard($user);
  }
  elsif ($action eq 'categories' || $action eq 'cats') {
    @return = trivia_categories($user);
  }
  elsif ($action eq 'stats') {
    my $target = shift(@args) || '';
    @return = trivia_stats($user, $target);
  }
  else {
    @return = trivia_help($user);
  }

  return @return;
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  # Fast bail if no game active
  return @return unless $DCBCommon::COMMON->{trivia} && $DCBCommon::COMMON->{trivia}->{active};

  # Don't process bot messages
  return @return unless $user->{uid} && $user->{uid} > 1;

  my $game = $DCBCommon::COMMON->{trivia};
  my $q = $game->{current_q};
  return @return unless $q;

  # Check if user's chat matches any accepted answer
  my $answer = lc($chat);
  $answer =~ s/^\s+|\s+$//g;

  foreach my $accepted (@{$q->{answers}}) {
    if ($answer eq lc($accepted)) {
      @return = trivia_correct_answer($user, $q);
      last;
    }
  }

  return @return;
}

sub timer {
  # Fast bail if no game active
  return unless $DCBCommon::COMMON->{trivia} && $DCBCommon::COMMON->{trivia}->{active};

  my $game = $DCBCommon::COMMON->{trivia};
  return unless $game->{asked_time};

  my $timeout = DCBSettings::config_get('trivia_timeout') || 30;
  if (time() - $game->{asked_time} >= $timeout) {
    my $q = $game->{current_q};
    my @return = ();

    my $answer_display = $q->{answers}->[0];
    push(@return, {
      param   => "message",
      message => "--- TIME'S UP! The answer was: $answer_display ---",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });

    # Mark wrong for everyone who didn't answer
    # Reset all active streaks
    foreach my $uid (keys %{$game->{streaks}}) {
      $game->{streaks}->{$uid} = 0;
    }

    $game->{current_index}++;
    if ($game->{current_index} < $game->{round_total}) {
      push(@return, trivia_ask_question());
    }
    else {
      push(@return, trivia_end_round());
    }
    return @return;
  }
  return;
}

# --- Game Control ---

sub trivia_start {
  my ($user, @args) = @_;
  my @return = ();

  if ($DCBCommon::COMMON->{trivia} && $DCBCommon::COMMON->{trivia}->{active}) {
    return ({
      param   => "message",
      message => "A trivia game is already in progress! Use -trivia stop to end it.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $rounds = DCBSettings::config_get('trivia_default_rounds') || 10;
  my $category_filter = '';

  foreach my $arg (@args) {
    if ($arg =~ /^\d+$/ && $arg > 0 && $arg <= 50) {
      $rounds = $arg;
    }
    elsif ($arg =~ /^[a-zA-Z]/) {
      $category_filter = lc($arg);
    }
  }

  # Build question pool
  my @pool = trivia_get_questions();

  if ($category_filter) {
    @pool = grep { lc($_->{category}) eq $category_filter } @pool;
    if (!@pool) {
      return ({
        param   => "message",
        message => "No questions found for category '$category_filter'. Use -trivia categories to see available categories.",
        user    => $user->{name},
        touser  => '',
        type    => MESSAGE->{'PUBLIC_SINGLE'},
      });
    }
  }

  @pool = shuffle(@pool);
  $rounds = scalar(@pool) if $rounds > scalar(@pool);
  my @questions = @pool[0 .. $rounds - 1];

  # Initialize game state
  $DCBCommon::COMMON->{trivia} = {
    active          => 1,
    questions       => \@questions,
    current_index   => 0,
    current_q       => undef,
    asked_time      => 0,
    scores          => {},
    streaks         => {},
    round_total     => $rounds,
    category_filter => $category_filter,
    starter_uid     => $user->{uid},
  };

  my $cat_msg = $category_filter ? " (Category: \U$category_filter\E)" : '';
  push(@return, {
    param   => "message",
    message => "*** TRIVIA GAME STARTED by $user->{name}! $rounds questions$cat_msg ***\nType your answers in chat. You have " . (DCBSettings::config_get('trivia_timeout') || 30) . " seconds per question.\nScoring: Easy=1pt, Medium=2pt, Hard=3pt + streak bonuses!",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });

  push(@return, trivia_ask_question());
  return @return;
}

sub trivia_stop {
  my ($user) = @_;

  if (!$DCBCommon::COMMON->{trivia} || !$DCBCommon::COMMON->{trivia}->{active}) {
    return ({
      param   => "message",
      message => "No trivia game is currently running.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $game = $DCBCommon::COMMON->{trivia};
  # Only starter or operators can stop
  if ($user->{uid} != $game->{starter_uid} && !DCBUser::user_is_admin($user)) {
    return ({
      param   => "message",
      message => "Only the game starter or an operator can stop the trivia game.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my @return = ();
  push(@return, {
    param   => "message",
    message => "*** TRIVIA GAME STOPPED by $user->{name} ***",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
  push(@return, trivia_end_round());
  return @return;
}

sub trivia_ask_question {
  my @return = ();
  my $game = $DCBCommon::COMMON->{trivia};
  my $q = $game->{questions}->[$game->{current_index}];
  $game->{current_q} = $q;
  $game->{asked_time} = time();

  my $num = $game->{current_index} + 1;
  my $total = $game->{round_total};
  my $diff_stars = $q->{difficulty} eq 'easy' ? '*' : $q->{difficulty} eq 'medium' ? '**' : '***';

  push(@return, {
    param   => "message",
    message => "\n--- Question $num/$total [$q->{category}] ($diff_stars $q->{difficulty}, $q->{points}pt) ---\n$q->{question}",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });

  return @return;
}

sub trivia_correct_answer {
  my ($user, $q) = @_;
  my @return = ();
  my $game = $DCBCommon::COMMON->{trivia};

  my $points = $q->{points};
  my $uid = $user->{uid};

  # Track streak
  $game->{streaks}->{$uid} = ($game->{streaks}->{$uid} || 0) + 1;
  my $streak = $game->{streaks}->{$uid};
  my $streak_bonus_interval = 3;
  my $streak_bonus = DCBSettings::config_get('trivia_streak_bonus') || 2;
  my $bonus = 0;
  if ($streak > 0 && $streak % $streak_bonus_interval == 0) {
    $bonus = $streak_bonus;
    $points += $bonus;
  }

  # Update round scores
  $game->{scores}->{$uid} = ($game->{scores}->{$uid} || 0) + $points;

  # Persist to DB
  trivia_update_score($uid, $points, 1, $streak);

  # Award rank XP for correct trivia answer
  eval {
    if ($DCBCommon::COMMON->{ranks}) {
      my $trivia_xp = DCBSettings::config_get('ranks_xp_trivia_correct') || 10;
      push(@return, ranks::ranks_add_xp($user, $trivia_xp, 'trivia_xp'));
    }
  };

  my $elapsed = time() - $game->{asked_time};
  my $streak_msg = $bonus > 0 ? " [STREAK x$streak! +${bonus} bonus]" : '';
  my $speed_msg = $elapsed <= 3 ? ' LIGHTNING FAST!' : '';

  push(@return, {
    param   => "message",
    message => "*** $user->{name} got it! (+${points}pts in ${elapsed}s)$streak_msg$speed_msg ***\nThe answer was: $q->{answers}->[0]",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });

  # Reset other players' streaks
  foreach my $other_uid (keys %{$game->{streaks}}) {
    next if $other_uid == $uid;
    $game->{streaks}->{$other_uid} = 0;
  }

  # Next question or end
  $game->{current_index}++;
  $game->{current_q} = undef;
  $game->{asked_time} = 0;

  if ($game->{current_index} < $game->{round_total}) {
    push(@return, trivia_ask_question());
  }
  else {
    push(@return, trivia_end_round());
  }

  return @return;
}

sub trivia_end_round {
  my @return = ();
  my $game = $DCBCommon::COMMON->{trivia};

  if ($game->{scores} && keys %{$game->{scores}}) {
    my $scoreboard = "*** FINAL SCORES ***\n";
    my $rank = 1;
    foreach my $uid (sort { $game->{scores}->{$b} <=> $game->{scores}->{$a} } keys %{$game->{scores}}) {
      my $u = DCBUser::user_load($uid);
      my $name = $u ? $u->{name} : "Unknown";
      my $medal = $rank == 1 ? '[WINNER] ' : $rank == 2 ? '[2nd] ' : $rank == 3 ? '[3rd] ' : '';
      $scoreboard .= "$medal$name: $game->{scores}->{$uid} points\n";

      # Award bonus rank XP to winner
      if ($rank == 1 && $u && $DCBCommon::COMMON->{ranks}) {
        eval {
          my $win_xp = DCBSettings::config_get('ranks_xp_trivia_win') || 50;
          push(@return, ranks::ranks_add_xp($u, $win_xp, 'trivia_xp'));
        };
      }

      $rank++;
    }
    push(@return, {
      param   => "message",
      message => $scoreboard,
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });
  }
  else {
    push(@return, {
      param   => "message",
      message => "*** TRIVIA ROUND OVER - No correct answers! Better luck next time! ***",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });
  }

  # Reset game state
  $DCBCommon::COMMON->{trivia} = { active => 0 };

  return @return;
}

# --- Score Persistence ---

sub trivia_update_score {
  my ($uid, $points, $correct, $streak) = @_;

  my @fields = ('*');
  my %where = ('uid' => $uid);
  my $sth = DCBDatabase::db_select('trivia_scores', \@fields, \%where);
  my $row = $sth->fetchrow_hashref();

  if ($row) {
    my $best_streak = $row->{streak_best} || 0;
    $best_streak = $streak if $streak > $best_streak;
    my %update = (
      'correct'     => ($row->{correct} || 0) + $correct,
      'points'      => ($row->{points} || 0) + $points,
      'streak_best' => $best_streak,
    );
    DCBDatabase::db_update('trivia_scores', \%update, \%where);
  }
  else {
    my %insert = (
      'uid'         => $uid,
      'correct'     => $correct,
      'wrong'       => 0,
      'streak_best' => $streak,
      'points'      => $points,
    );
    DCBDatabase::db_insert('trivia_scores', \%insert);
  }
}

# --- Display Commands ---

sub trivia_leaderboard {
  my ($user) = @_;

  my @fields = ('uid', 'correct', 'points', 'streak_best');
  my $order = {-desc => 'points'};
  my $sth = DCBDatabase::db_select('trivia_scores', \@fields, {}, $order, 10);

  my $message = "*** TRIVIA LEADERBOARD (Top 10) ***\n";
  my $rank = 1;
  my $found = 0;
  while (my $row = $sth->fetchrow_hashref()) {
    $found = 1;
    my $u = DCBUser::user_load($row->{uid});
    my $name = $u ? $u->{name} : "Unknown";
    $message .= "#$rank $name - $row->{points}pts ($row->{correct} correct, best streak: $row->{streak_best})\n";
    $rank++;
  }

  if (!$found) {
    $message .= "No scores yet! Start a game with -trivia start\n";
  }

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub trivia_stats {
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
  my $sth = DCBDatabase::db_select('trivia_scores', \@fields, \%where);
  my $row = $sth->fetchrow_hashref();

  my $message = '';
  if ($row) {
    $message = "*** Trivia Stats for $target->{name} ***\n";
    $message .= "Total Points: $row->{points}\n";
    $message .= "Correct Answers: $row->{correct}\n";
    $message .= "Best Streak: $row->{streak_best}\n";
  }
  else {
    $message = "$target->{name} hasn't played trivia yet!";
  }

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub trivia_categories {
  my ($user) = @_;

  my %cats = ();
  foreach my $q (trivia_get_questions()) {
    $cats{$q->{category}}++;
  }

  my $message = "*** TRIVIA CATEGORIES ***\n";
  foreach my $cat (sort keys %cats) {
    $message .= "$cat ($cats{$cat} questions)\n";
  }
  $message .= "\nUse: -trivia start [rounds] [category]";

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub trivia_help {
  my ($user) = @_;
  my $message = "*** TRIVIA COMMANDS ***\n";
  $message .= "-trivia start [rounds] [category] - Start a new game\n";
  $message .= "-trivia stop - End the current game\n";
  $message .= "-trivia scores - View the all-time leaderboard\n";
  $message .= "-trivia stats [user] - View trivia stats\n";
  $message .= "-trivia categories - List available categories\n";
  $message .= "\nDuring a game, just type your answer in chat!";

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

# --- Question Bank ---

sub trivia_get_questions {
  return (
    # === SCIENCE ===
    { category => 'Science', difficulty => 'easy', points => 1, question => 'What planet is known as the Red Planet?', answers => ['mars'] },
    { category => 'Science', difficulty => 'easy', points => 1, question => 'What gas do plants absorb from the atmosphere?', answers => ['carbon dioxide', 'co2'] },
    { category => 'Science', difficulty => 'easy', points => 1, question => 'How many bones are in the adult human body?', answers => ['206'] },
    { category => 'Science', difficulty => 'easy', points => 1, question => 'What is the chemical symbol for gold?', answers => ['au'] },
    { category => 'Science', difficulty => 'easy', points => 1, question => 'What is the largest organ of the human body?', answers => ['skin', 'the skin'] },
    { category => 'Science', difficulty => 'easy', points => 1, question => 'What force keeps us on the ground?', answers => ['gravity'] },
    { category => 'Science', difficulty => 'easy', points => 1, question => 'What is the boiling point of water in Celsius?', answers => ['100', '100 degrees', '100c'] },
    { category => 'Science', difficulty => 'medium', points => 2, question => 'What is the powerhouse of the cell?', answers => ['mitochondria', 'the mitochondria', 'mitochondrion'] },
    { category => 'Science', difficulty => 'medium', points => 2, question => 'What element has the atomic number 1?', answers => ['hydrogen'] },
    { category => 'Science', difficulty => 'medium', points => 2, question => 'What is the speed of light in km/s (approximately)?', answers => ['300000', '299792'] },
    { category => 'Science', difficulty => 'medium', points => 2, question => 'What is the most abundant gas in Earth\'s atmosphere?', answers => ['nitrogen'] },
    { category => 'Science', difficulty => 'medium', points => 2, question => 'What type of rock is formed from cooled lava?', answers => ['igneous'] },
    { category => 'Science', difficulty => 'medium', points => 2, question => 'What is the chemical formula for table salt?', answers => ['nacl'] },
    { category => 'Science', difficulty => 'medium', points => 2, question => 'How many chromosomes do humans have?', answers => ['46'] },
    { category => 'Science', difficulty => 'hard', points => 3, question => 'What is the Schwarzschild radius associated with?', answers => ['black hole', 'black holes', 'event horizon'] },
    { category => 'Science', difficulty => 'hard', points => 3, question => 'What particle is exchanged in electromagnetic interactions?', answers => ['photon', 'photons', 'virtual photon'] },
    { category => 'Science', difficulty => 'hard', points => 3, question => 'What is the half-life of Carbon-14 in years (approximately)?', answers => ['5730', '5700'] },
    { category => 'Science', difficulty => 'hard', points => 3, question => 'What is the name of the boundary between the crust and the mantle?', answers => ['moho', 'mohorovicic discontinuity'] },

    # === HISTORY ===
    { category => 'History', difficulty => 'easy', points => 1, question => 'In what year did World War II end?', answers => ['1945'] },
    { category => 'History', difficulty => 'easy', points => 1, question => 'Who was the first President of the United States?', answers => ['george washington', 'washington'] },
    { category => 'History', difficulty => 'easy', points => 1, question => 'What ancient civilization built the pyramids at Giza?', answers => ['egypt', 'egyptian', 'egyptians', 'ancient egypt'] },
    { category => 'History', difficulty => 'easy', points => 1, question => 'What ship sank on its maiden voyage in 1912?', answers => ['titanic', 'the titanic', 'rms titanic'] },
    { category => 'History', difficulty => 'easy', points => 1, question => 'What wall fell in 1989?', answers => ['berlin wall', 'the berlin wall'] },
    { category => 'History', difficulty => 'easy', points => 1, question => 'Who painted the Mona Lisa?', answers => ['leonardo da vinci', 'da vinci', 'leonardo'] },
    { category => 'History', difficulty => 'medium', points => 2, question => 'What year was the Declaration of Independence signed?', answers => ['1776'] },
    { category => 'History', difficulty => 'medium', points => 2, question => 'Who was the first person to walk on the Moon?', answers => ['neil armstrong', 'armstrong'] },
    { category => 'History', difficulty => 'medium', points => 2, question => 'What empire was ruled by Genghis Khan?', answers => ['mongol empire', 'mongol', 'mongols'] },
    { category => 'History', difficulty => 'medium', points => 2, question => 'In what year did the French Revolution begin?', answers => ['1789'] },
    { category => 'History', difficulty => 'medium', points => 2, question => 'What was the name of the first artificial satellite launched into space?', answers => ['sputnik', 'sputnik 1'] },
    { category => 'History', difficulty => 'medium', points => 2, question => 'Which Roman Emperor made Christianity the state religion?', answers => ['theodosius', 'theodosius i', 'theodosius the great'] },
    { category => 'History', difficulty => 'hard', points => 3, question => 'What treaty ended World War I?', answers => ['treaty of versailles', 'versailles'] },
    { category => 'History', difficulty => 'hard', points => 3, question => 'In what year was the Magna Carta signed?', answers => ['1215'] },
    { category => 'History', difficulty => 'hard', points => 3, question => 'What was the last dynasty to rule China?', answers => ['qing', 'qing dynasty', 'manchu'] },
    { category => 'History', difficulty => 'hard', points => 3, question => 'Who led the Carthaginian army across the Alps?', answers => ['hannibal', 'hannibal barca'] },

    # === GEOGRAPHY ===
    { category => 'Geography', difficulty => 'easy', points => 1, question => 'What is the largest continent by area?', answers => ['asia'] },
    { category => 'Geography', difficulty => 'easy', points => 1, question => 'What is the longest river in the world?', answers => ['nile', 'the nile', 'river nile'] },
    { category => 'Geography', difficulty => 'easy', points => 1, question => 'What country has the most people?', answers => ['india', 'china'] },
    { category => 'Geography', difficulty => 'easy', points => 1, question => 'What is the capital of Australia?', answers => ['canberra'] },
    { category => 'Geography', difficulty => 'easy', points => 1, question => 'What ocean is the largest?', answers => ['pacific', 'pacific ocean', 'the pacific'] },
    { category => 'Geography', difficulty => 'easy', points => 1, question => 'What is the smallest country in the world?', answers => ['vatican city', 'vatican', 'the vatican'] },
    { category => 'Geography', difficulty => 'medium', points => 2, question => 'What is the capital of Mongolia?', answers => ['ulaanbaatar', 'ulan bator'] },
    { category => 'Geography', difficulty => 'medium', points => 2, question => 'What is the deepest ocean trench?', answers => ['mariana trench', 'mariana', 'marianas trench'] },
    { category => 'Geography', difficulty => 'medium', points => 2, question => 'What African country was formerly known as Abyssinia?', answers => ['ethiopia'] },
    { category => 'Geography', difficulty => 'medium', points => 2, question => 'What is the driest continent on Earth?', answers => ['antarctica'] },
    { category => 'Geography', difficulty => 'medium', points => 2, question => 'What mountain is the tallest in the world?', answers => ['everest', 'mount everest', 'mt everest'] },
    { category => 'Geography', difficulty => 'medium', points => 2, question => 'What country has the most time zones?', answers => ['france'] },
    { category => 'Geography', difficulty => 'hard', points => 3, question => 'What is the capital of Burkina Faso?', answers => ['ouagadougou'] },
    { category => 'Geography', difficulty => 'hard', points => 3, question => 'What is the longest mountain range in the world?', answers => ['andes', 'the andes'] },
    { category => 'Geography', difficulty => 'hard', points => 3, question => 'What strait separates Europe from Africa?', answers => ['strait of gibraltar', 'gibraltar'] },
    { category => 'Geography', difficulty => 'hard', points => 3, question => 'What is the largest desert in the world?', answers => ['antarctic desert', 'antarctica', 'sahara'] },

    # === MOVIES ===
    { category => 'Movies', difficulty => 'easy', points => 1, question => 'What 1994 film features a man sitting on a bench telling his life story?', answers => ['forrest gump'] },
    { category => 'Movies', difficulty => 'easy', points => 1, question => 'Who directed Jurassic Park?', answers => ['steven spielberg', 'spielberg'] },
    { category => 'Movies', difficulty => 'easy', points => 1, question => 'What superhero is also known as the Dark Knight?', answers => ['batman'] },
    { category => 'Movies', difficulty => 'easy', points => 1, question => 'In The Matrix, which pill does Neo take?', answers => ['red', 'red pill', 'the red pill'] },
    { category => 'Movies', difficulty => 'easy', points => 1, question => 'What is the name of the hobbit played by Elijah Wood in Lord of the Rings?', answers => ['frodo', 'frodo baggins'] },
    { category => 'Movies', difficulty => 'easy', points => 1, question => 'What animated film features a clownfish named Marlin searching for his son?', answers => ['finding nemo'] },
    { category => 'Movies', difficulty => 'medium', points => 2, question => 'What 1999 film has the quote "I see dead people"?', answers => ['the sixth sense', 'sixth sense'] },
    { category => 'Movies', difficulty => 'medium', points => 2, question => 'Who played The Joker in The Dark Knight (2008)?', answers => ['heath ledger', 'ledger'] },
    { category => 'Movies', difficulty => 'medium', points => 2, question => 'What film won the first Academy Award for Best Picture?', answers => ['wings'] },
    { category => 'Movies', difficulty => 'medium', points => 2, question => 'In what fictional city does Batman operate?', answers => ['gotham', 'gotham city'] },
    { category => 'Movies', difficulty => 'medium', points => 2, question => 'What is the highest-grossing film of all time (not adjusted for inflation)?', answers => ['avatar'] },
    { category => 'Movies', difficulty => 'hard', points => 3, question => 'What was Stanley Kubrick\'s last film before his death?', answers => ['eyes wide shut'] },
    { category => 'Movies', difficulty => 'hard', points => 3, question => 'Who directed the 1982 film Blade Runner?', answers => ['ridley scott', 'scott'] },
    { category => 'Movies', difficulty => 'hard', points => 3, question => 'What 1957 film by Akira Kurosawa was remade as The Magnificent Seven?', answers => ['seven samurai', 'the seven samurai'] },

    # === MUSIC ===
    { category => 'Music', difficulty => 'easy', points => 1, question => 'What band was Freddie Mercury the lead singer of?', answers => ['queen'] },
    { category => 'Music', difficulty => 'easy', points => 1, question => 'What instrument has 88 keys?', answers => ['piano', 'the piano'] },
    { category => 'Music', difficulty => 'easy', points => 1, question => 'Who is known as the King of Pop?', answers => ['michael jackson', 'jackson'] },
    { category => 'Music', difficulty => 'easy', points => 1, question => 'What band performed "Bohemian Rhapsody"?', answers => ['queen'] },
    { category => 'Music', difficulty => 'easy', points => 1, question => 'How many strings does a standard guitar have?', answers => ['6', 'six'] },
    { category => 'Music', difficulty => 'easy', points => 1, question => 'What Beatles album features a zebra crossing on the cover?', answers => ['abbey road'] },
    { category => 'Music', difficulty => 'medium', points => 2, question => 'Who wrote the Four Seasons?', answers => ['vivaldi', 'antonio vivaldi'] },
    { category => 'Music', difficulty => 'medium', points => 2, question => 'What band had members named Angus and Malcolm Young?', answers => ['ac/dc', 'acdc'] },
    { category => 'Music', difficulty => 'medium', points => 2, question => 'What artist released the album "The Dark Side of the Moon"?', answers => ['pink floyd'] },
    { category => 'Music', difficulty => 'medium', points => 2, question => 'What is the real name of Bono from U2?', answers => ['paul hewson', 'paul david hewson'] },
    { category => 'Music', difficulty => 'medium', points => 2, question => 'What instrument does Yo-Yo Ma play?', answers => ['cello', 'the cello'] },
    { category => 'Music', difficulty => 'hard', points => 3, question => 'What composer went deaf but continued to compose?', answers => ['beethoven', 'ludwig van beethoven'] },
    { category => 'Music', difficulty => 'hard', points => 3, question => 'What rock band was formerly known as "On a Friday"?', answers => ['radiohead'] },
    { category => 'Music', difficulty => 'hard', points => 3, question => 'What is the time signature of a waltz?', answers => ['3/4', '3 4'] },

    # === GENERAL KNOWLEDGE ===
    { category => 'General', difficulty => 'easy', points => 1, question => 'How many days are in a leap year?', answers => ['366'] },
    { category => 'General', difficulty => 'easy', points => 1, question => 'What colour are emeralds?', answers => ['green'] },
    { category => 'General', difficulty => 'easy', points => 1, question => 'How many sides does a hexagon have?', answers => ['6', 'six'] },
    { category => 'General', difficulty => 'easy', points => 1, question => 'What is the main ingredient in guacamole?', answers => ['avocado'] },
    { category => 'General', difficulty => 'easy', points => 1, question => 'How many players are on a soccer team on the field?', answers => ['11', 'eleven'] },
    { category => 'General', difficulty => 'easy', points => 1, question => 'What language has the most native speakers?', answers => ['mandarin', 'mandarin chinese', 'chinese'] },
    { category => 'General', difficulty => 'easy', points => 1, question => 'What is the hardest natural substance on Earth?', answers => ['diamond'] },
    { category => 'General', difficulty => 'medium', points => 2, question => 'What does "HTTP" stand for?', answers => ['hypertext transfer protocol'] },
    { category => 'General', difficulty => 'medium', points => 2, question => 'What year was the first iPhone released?', answers => ['2007'] },
    { category => 'General', difficulty => 'medium', points => 2, question => 'What board game has properties like Park Place and Boardwalk?', answers => ['monopoly'] },
    { category => 'General', difficulty => 'medium', points => 2, question => 'How many cards are in a standard deck (no jokers)?', answers => ['52'] },
    { category => 'General', difficulty => 'medium', points => 2, question => 'What chess piece can only move diagonally?', answers => ['bishop', 'the bishop'] },
    { category => 'General', difficulty => 'medium', points => 2, question => 'What is the most widely spoken language in the world?', answers => ['english'] },
    { category => 'General', difficulty => 'hard', points => 3, question => 'What is the only number that is twice the sum of its digits?', answers => ['18'] },
    { category => 'General', difficulty => 'hard', points => 3, question => 'What year was the World Wide Web invented?', answers => ['1989'] },
    { category => 'General', difficulty => 'hard', points => 3, question => 'What does the "S" in "HTTPS" stand for?', answers => ['secure'] },
    { category => 'General', difficulty => 'hard', points => 3, question => 'What programming language was created by Guido van Rossum?', answers => ['python'] },

    # === TECHNOLOGY ===
    { category => 'Technology', difficulty => 'easy', points => 1, question => 'What does "CPU" stand for?', answers => ['central processing unit'] },
    { category => 'Technology', difficulty => 'easy', points => 1, question => 'What company makes the iPhone?', answers => ['apple'] },
    { category => 'Technology', difficulty => 'easy', points => 1, question => 'What does "Wi-Fi" most commonly connect you to?', answers => ['the internet', 'internet', 'a network', 'network'] },
    { category => 'Technology', difficulty => 'medium', points => 2, question => 'What programming language is known for its use in web browsers?', answers => ['javascript', 'js'] },
    { category => 'Technology', difficulty => 'medium', points => 2, question => 'What does "RAM" stand for?', answers => ['random access memory'] },
    { category => 'Technology', difficulty => 'medium', points => 2, question => 'Who is the co-founder of Microsoft alongside Bill Gates?', answers => ['paul allen', 'allen'] },
    { category => 'Technology', difficulty => 'medium', points => 2, question => 'What protocol is used to send email?', answers => ['smtp', 'simple mail transfer protocol'] },
    { category => 'Technology', difficulty => 'hard', points => 3, question => 'In what year was Linux first released?', answers => ['1991'] },
    { category => 'Technology', difficulty => 'hard', points => 3, question => 'What does "SQL" stand for?', answers => ['structured query language'] },
    { category => 'Technology', difficulty => 'hard', points => 3, question => 'What company developed the Git version control system?', answers => ['none', 'linus torvalds', 'torvalds'] },
  );
}

1;
