package wordle;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;
use POSIX qw(floor);

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  my $action = lc($chat);
  $action =~ s/^\s+|\s+$//g;

  if ($action eq 'start' || $action eq '') {
    return wordle_start($user);
  }
  elsif ($action eq 'stop' || $action eq 'give up' || $action eq 'giveup') {
    return wordle_giveup($user);
  }
  elsif ($action eq 'help') {
    return wordle_help($user);
  }
  else {
    return wordle_help($user);
  }
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  # Fast bail
  return @return unless $DCBCommon::COMMON->{wordle} && $DCBCommon::COMMON->{wordle}->{active};
  return @return unless $user->{uid} && $user->{uid} > 1;

  my $guess = lc($chat);
  $guess =~ s/^\s+|\s+$//g;

  # Must be exactly 5 letters
  return @return unless $guess =~ /^[a-z]{5}$/;

  return wordle_guess($user, $guess);
}

# --- Game Logic ---

sub wordle_start {
  my ($user) = @_;

  if ($DCBCommon::COMMON->{wordle} && $DCBCommon::COMMON->{wordle}->{active}) {
    my $game = $DCBCommon::COMMON->{wordle};
    my $tries_left = 6 - scalar(@{$game->{guesses}});
    return ({
      param   => "message",
      message => "Wordle already in progress! $tries_left guesses left.\nType a 5-letter word to guess!",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  # Pick today's word (deterministic based on day)
  my @words = wordle_words();
  my $day = floor(time() / 86400);
  my $word = $words[$day % scalar(@words)];

  $DCBCommon::COMMON->{wordle} = {
    active  => 1,
    word    => $word,
    guesses => [],
    starter => $user->{uid},
    players => {},
  };

  return ({
    param   => "message",
    message => "*** WORDLE started by $user->{name}! ***\nGuess the 5-letter word in 6 tries.\nType any 5-letter word to guess.\n[=] = correct position, [~] = wrong position, [.] = not in word",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub wordle_guess {
  my ($user, $guess) = @_;
  my @return = ();
  my $game = $DCBCommon::COMMON->{wordle};
  my $word = $game->{word};

  # Track who played
  $game->{players}->{$user->{uid}} = 1;

  # Evaluate guess
  my @result = ();
  my @word_chars = split(//, $word);
  my @guess_chars = split(//, $guess);
  my @used = (0) x 5;

  # First pass: exact matches
  for (my $i = 0; $i < 5; $i++) {
    if ($guess_chars[$i] eq $word_chars[$i]) {
      $result[$i] = '=';
      $used[$i] = 1;
    }
  }

  # Second pass: wrong position
  for (my $i = 0; $i < 5; $i++) {
    next if $result[$i];
    my $found = 0;
    for (my $j = 0; $j < 5; $j++) {
      if (!$used[$j] && $guess_chars[$i] eq $word_chars[$j]) {
        $result[$i] = '~';
        $used[$j] = 1;
        $found = 1;
        last;
      }
    }
    $result[$i] = '.' unless $found;
  }

  # Build display
  my $display = '';
  for (my $i = 0; $i < 5; $i++) {
    $display .= "[$result[$i]]" . uc($guess_chars[$i]) . " ";
  }

  push(@{$game->{guesses}}, { guess => $guess, display => $display, user => $user->{name} });

  # Check win
  if ($guess eq $word) {
    my $tries = scalar(@{$game->{guesses}});
    my $history = wordle_format_history($game);

    push(@return, {
      param   => "message",
      message => "$history\n*** $user->{name} solved it in $tries/6 guesses! ***",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });

    # XP based on how few guesses
    eval {
      if ($DCBCommon::COMMON->{ranks}) {
        my $xp = (7 - $tries) * 5;
        push(@return, ranks::ranks_add_xp($user, $xp, 'social_xp'));
      }
    };

    $DCBCommon::COMMON->{wordle} = { active => 0 };
  }
  elsif (scalar(@{$game->{guesses}}) >= 6) {
    my $history = wordle_format_history($game);

    push(@return, {
      param   => "message",
      message => "$history\n*** GAME OVER! The word was: $word ***",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });

    $DCBCommon::COMMON->{wordle} = { active => 0 };
  }
  else {
    my $tries_left = 6 - scalar(@{$game->{guesses}});
    push(@return, {
      param   => "message",
      message => "$display ($user->{name}) - $tries_left guesses left",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub wordle_giveup {
  my ($user) = @_;

  if (!$DCBCommon::COMMON->{wordle} || !$DCBCommon::COMMON->{wordle}->{active}) {
    return ({
      param   => "message",
      message => "No wordle game running. Use -wordle to start one!",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $word = $DCBCommon::COMMON->{wordle}->{word};
  $DCBCommon::COMMON->{wordle} = { active => 0 };

  return ({
    param   => "message",
    message => "*** Wordle abandoned. The word was: $word ***",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub wordle_format_history {
  my ($game) = @_;
  my $history = "*** WORDLE ***\n";
  foreach my $g (@{$game->{guesses}}) {
    $history .= "$g->{display}  ($g->{user})\n";
  }
  return $history;
}

sub wordle_help {
  my ($user) = @_;
  return ({
    param   => "message",
    message => "*** WORDLE ***\n-wordle - Start a new game\n-wordle stop - Give up\n\nDuring a game, type any 5-letter word to guess.\n[=] = letter in correct position\n[~] = letter in word but wrong position\n[.] = letter not in word\n\n6 guesses to find the word!",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

# --- Word List (common 5-letter words) ---

sub wordle_words {
  return qw(
    about above abuse actor acute admit adopt adult after again agent agree ahead alarm album
    alert alien align alive allow alone alter among angel anger angle angry apart apple apply
    arena argue arise array aside asset avoid award aware badly baker bases basic basis beach
    began begin being below bench birth black blade blame blank blast blaze bleed blend bless
    blind block blood bloom blown board boost bound brain brand brave bread break breed brick
    brief bring broad broke brown brush build burst buyer cabin cable candy cargo carry catch
    cause chain chair chaos charm chase cheap check chess chief child china chose civil claim
    class clean clear climb clock close cloud coach coast could count court cover crack craft
    crash crazy cream crime cross crowd crown crush curve cycle daily dance death debug delay
    delta depth dirty doubt draft drain drama drawn dream dress drift drink drive eager early
    earth eight elite email empty enemy enjoy enter equal error essay event every exact exist
    extra faith false fault fence fewer fiber field fight final flash fleet flesh float flood
    floor fluid focus force found frame frank fraud fresh front fruit fully funny ghost giant
    given glass globe going grace grade grain grand grant grass grave great green gross group
    grown guard guess guide happy harsh heart heavy hence honor horse hotel house human humor
    ideal image imply index inner input issue ivory joint judge juice known label large laser
    later laugh layer learn least legal level light limit linen liver lodge logic loose lover
    lower lucky lunch magic major maker manor match mayor media metal might minor minus model
    money month moral motor mount mouse mouth movie music naive nerve never night noble noise
    north novel nurse ocean offer often order other outer panel paper party patch pause peace
    phase phone photo piano piece pilot pitch place plain plane plant plate plaza plead point
    pound power press price pride prime print prior proof proud prove psalm queen query quick
    quiet quote radar raise range rapid ratio reach realm reign relax reply rider ridge rifle
    right risky rival river robot rough round route royal rural salad scale scene scope score
    sense serve seven shade shake shall shape share shark sharp shelf shell shift shine shirt
    shock shoot shore short shout sight since sixty skill sleep slice slide small smart smile
    smoke solid solve sorry sound south space spare speak speed spend split spoke sport squad
    stack staff stage stake stand start state steam steel steep stick still stock stone stood
    store storm story stuff style sugar suite super surge sweet swift sword table taste teach
    theme thick thing think third those three throw tight timer title today total touch tough
    tower trace track trade trail train trait treat trend trial trick truck truly trump trunk
    trust truth twice ultra under union unite unity until upper urban usage usual valid value
    video virus visit vital vocal voice waste watch water weigh wheel where which while white
    whole whose width woman world worry worse worst worth would wound write wrong yacht young
    youth
  );
}

1;
