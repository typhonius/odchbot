package hangman;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use DCBCommon;
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  my $action = lc($chat);
  $action =~ s/^\s+|\s+$//g;

  if ($action eq 'start' || $action eq '') {
    return hangman_start($user);
  }
  elsif ($action eq 'stop') {
    return hangman_stop($user);
  }
  elsif ($action eq 'help') {
    return hangman_help($user);
  }
  else {
    return hangman_help($user);
  }
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  # Fast bail
  return @return unless $DCBCommon::COMMON->{hangman} && $DCBCommon::COMMON->{hangman}->{active};
  return @return unless $user->{uid} && $user->{uid} > 1;

  my $guess = lc($chat);
  $guess =~ s/^\s+|\s+$//g;

  # Single letter guess
  if ($guess =~ /^[a-z]$/) {
    return hangman_guess_letter($user, $guess);
  }
  # Full word guess
  elsif ($DCBCommon::COMMON->{hangman}->{word} && $guess =~ /^[a-z]{2,}$/ && length($guess) == length($DCBCommon::COMMON->{hangman}->{word})) {
    return hangman_guess_word($user, $guess);
  }

  return @return;
}

# --- Game Logic ---

sub hangman_start {
  my ($user) = @_;

  if ($DCBCommon::COMMON->{hangman} && $DCBCommon::COMMON->{hangman}->{active}) {
    my $game = $DCBCommon::COMMON->{hangman};
    my $display = hangman_display($game);
    return ({
      param   => "message",
      message => "Game already in progress!\n$display\nGuessed: " . join(', ', sort keys %{$game->{guessed}}) . "\nLives: $game->{lives}/6",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my @words = hangman_words();
  my $word = $words[int(rand(scalar @words))];

  $DCBCommon::COMMON->{hangman} = {
    active  => 1,
    word    => lc($word),
    guessed => {},
    lives   => 6,
    starter => $user->{uid},
  };

  my $display = hangman_display($DCBCommon::COMMON->{hangman});

  return ({
    param   => "message",
    message => "*** HANGMAN started by $user->{name}! ***\n$display\nWord has " . length($word) . " letters. Guess by typing a single letter in chat!\n6 lives remaining.",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub hangman_stop {
  my ($user) = @_;

  if (!$DCBCommon::COMMON->{hangman} || !$DCBCommon::COMMON->{hangman}->{active}) {
    return ({
      param   => "message",
      message => "No hangman game running.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $word = $DCBCommon::COMMON->{hangman}->{word};
  $DCBCommon::COMMON->{hangman} = { active => 0 };

  return ({
    param   => "message",
    message => "*** Hangman stopped. The word was: $word ***",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub hangman_guess_letter {
  my ($user, $letter) = @_;
  my @return = ();
  my $game = $DCBCommon::COMMON->{hangman};

  if ($game->{guessed}->{$letter}) {
    return ({
      param   => "message",
      message => "'$letter' was already guessed!",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  $game->{guessed}->{$letter} = 1;

  if (index($game->{word}, $letter) >= 0) {
    # Correct guess
    my $display = hangman_display($game);

    # Check if word is complete
    if (hangman_is_solved($game)) {
      push(@return, {
        param   => "message",
        message => "*** $user->{name} guessed '$letter' - CORRECT! ***\nWord: $game->{word}\n*** CONGRATULATIONS! Word solved! ***",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });

      # Award rank XP
      eval {
        if ($DCBCommon::COMMON->{ranks}) {
          push(@return, ranks::ranks_add_xp($user, 10, 'social_xp'));
        }
      };

      $DCBCommon::COMMON->{hangman} = { active => 0 };
    }
    else {
      push(@return, {
        param   => "message",
        message => "$user->{name} guessed '$letter' - CORRECT!\n$display\nLives: $game->{lives}/6",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
    }
  }
  else {
    # Wrong guess
    $game->{lives}--;

    if ($game->{lives} <= 0) {
      push(@return, {
        param   => "message",
        message => "$user->{name} guessed '$letter' - WRONG!\n*** GAME OVER! The word was: $game->{word} ***",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
      $DCBCommon::COMMON->{hangman} = { active => 0 };
    }
    else {
      my $display = hangman_display($game);
      my $hangman_art = hangman_art($game->{lives});
      push(@return, {
        param   => "message",
        message => "$user->{name} guessed '$letter' - WRONG!\n$hangman_art\n$display\nLives: $game->{lives}/6 | Guessed: " . join(', ', sort keys %{$game->{guessed}}),
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
    }
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

sub hangman_guess_word {
  my ($user, $word) = @_;
  my @return = ();
  my $game = $DCBCommon::COMMON->{hangman};

  if ($word eq $game->{word}) {
    push(@return, {
      param   => "message",
      message => "*** $user->{name} guessed the whole word: $game->{word}! AMAZING! ***",
      user    => '',
      touser  => '',
      type    => MESSAGE->{'PUBLIC_ALL'},
    });

    eval {
      if ($DCBCommon::COMMON->{ranks}) {
        push(@return, ranks::ranks_add_xp($user, 20, 'social_xp'));
      }
    };

    $DCBCommon::COMMON->{hangman} = { active => 0 };
  }
  else {
    $game->{lives}--;
    if ($game->{lives} <= 0) {
      push(@return, {
        param   => "message",
        message => "$user->{name} guessed '$word' - WRONG!\n*** GAME OVER! The word was: $game->{word} ***",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
      $DCBCommon::COMMON->{hangman} = { active => 0 };
    }
    else {
      push(@return, {
        param   => "message",
        message => "$user->{name} guessed '$word' - WRONG! Lives: $game->{lives}/6",
        user    => '',
        touser  => '',
        type    => MESSAGE->{'PUBLIC_ALL'},
      });
    }
  }

  @return = grep { defined $_ && ref $_ eq 'HASH' } @return;
  return @return;
}

# --- Display ---

sub hangman_display {
  my ($game) = @_;
  my $word = $game->{word};
  my $display = '';
  foreach my $letter (split //, $word) {
    if ($game->{guessed}->{$letter}) {
      $display .= "$letter ";
    }
    else {
      $display .= "_ ";
    }
  }
  return $display;
}

sub hangman_is_solved {
  my ($game) = @_;
  foreach my $letter (split //, $game->{word}) {
    return 0 unless $game->{guessed}->{$letter};
  }
  return 1;
}

sub hangman_art {
  my ($lives) = @_;
  my @stages = (
    "  +---+\n  |   |\n  O   |\n /|\\  |\n / \\  |\n      |\n=========",
    "  +---+\n  |   |\n  O   |\n /|\\  |\n /    |\n      |\n=========",
    "  +---+\n  |   |\n  O   |\n /|\\  |\n      |\n      |\n=========",
    "  +---+\n  |   |\n  O   |\n /|   |\n      |\n      |\n=========",
    "  +---+\n  |   |\n  O   |\n  |   |\n      |\n      |\n=========",
    "  +---+\n  |   |\n  O   |\n      |\n      |\n      |\n=========",
    "  +---+\n  |   |\n      |\n      |\n      |\n      |\n=========",
  );
  $lives = 6 if $lives > 6;
  $lives = 0 if $lives < 0;
  return $stages[6 - $lives];
}

sub hangman_help {
  my ($user) = @_;
  return ({
    param   => "message",
    message => "*** HANGMAN ***\n-hangman - Start a new game\n-hangman stop - End current game\n\nDuring a game, type a single letter to guess!\nYou can also guess the whole word.",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

# --- Word List ---

sub hangman_words {
  return qw(
    computer keyboard monitor network protocol database
    algorithm function variable software hardware internet
    download bandwidth firewall encryption password server
    compiler debugger terminal processor memory graphics
    satellite asteroid telescope universe galaxy meteor
    dinosaur elephant giraffe penguin dolphin kangaroo
    mountain volcano tsunami avalanche earthquake hurricane
    chocolate espresso croissant spaghetti hamburger
    adventure treasure mystery detective pirate dragon
    symphony orchestra conductor symphony violin piano
    democracy parliament election republic monarchy
    telescope microscope laboratory experiment molecule
    architecture cathedral skyscraper pyramid colosseum
    mythology centaur phoenix minotaur labyrinth
    revolution industrial philosophy democracy medieval
  );
}

1;
