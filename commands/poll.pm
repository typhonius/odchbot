package poll;

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

  my @args = split(/\s+/, $chat, 2);
  my $action = lc($args[0] || 'status');
  my $rest = $args[1] || '';

  if ($action eq 'create' || $action eq 'new') {
    return poll_create($user, $rest);
  }
  elsif ($action eq 'end' || $action eq 'close') {
    return poll_end($user);
  }
  elsif ($action eq 'status' || $action eq 'results') {
    return poll_status($user);
  }
  elsif ($action =~ /^\d+$/) {
    return poll_vote($user, $action);
  }
  else {
    return poll_help($user);
  }
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  # Fast bail
  return @return unless $DCBCommon::COMMON->{poll} && $DCBCommon::COMMON->{poll}->{active};
  return @return unless $user->{uid} && $user->{uid} > 1;

  # Check if chat is just a number (quick vote)
  my $answer = $chat;
  $answer =~ s/^\s+|\s+$//g;
  if ($answer =~ /^(\d+)$/) {
    my $choice = $1;
    my $poll = $DCBCommon::COMMON->{poll};
    if ($choice >= 1 && $choice <= scalar(@{$poll->{options}})) {
      if (!$poll->{voters}->{$user->{uid}}) {
        push(@return, poll_vote($user, $choice));
      }
    }
  }

  return @return;
}

sub timer {
  return unless $DCBCommon::COMMON->{poll} && $DCBCommon::COMMON->{poll}->{active};

  my $poll = $DCBCommon::COMMON->{poll};
  # Auto-close after 5 minutes
  if ($poll->{time} && time() - $poll->{time} > 300) {
    my @return = ();
    push(@return, poll_finalize());
    return @return;
  }
  return;
}

# --- Logic ---

sub poll_create {
  my ($user, $text) = @_;

  if ($DCBCommon::COMMON->{poll} && $DCBCommon::COMMON->{poll}->{active}) {
    return ({
      param   => "message",
      message => "A poll is already active! Use -poll end to close it first.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  # Parse: "Question? | Option1 | Option2 | Option3"
  my @parts = split(/\s*\|\s*/, $text);
  if (scalar(@parts) < 3) {
    return ({
      param   => "message",
      message => "Usage: -poll create Question? | Option 1 | Option 2 | Option 3",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $question = shift(@parts);
  if (scalar(@parts) > 10) {
    return ({
      param   => "message",
      message => "Maximum 10 options allowed.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  $DCBCommon::COMMON->{poll} = {
    active   => 1,
    question => $question,
    options  => \@parts,
    votes    => {},
    voters   => {},
    creator  => $user->{uid},
    time     => time(),
  };

  # Initialize vote counts
  for (my $i = 0; $i < scalar(@parts); $i++) {
    $DCBCommon::COMMON->{poll}->{votes}->{$i + 1} = 0;
  }

  my $message = "*** NEW POLL by $user->{name} ***\n$question\n\n";
  for (my $i = 0; $i < scalar(@parts); $i++) {
    $message .= "  " . ($i + 1) . ") $parts[$i]\n";
  }
  $message .= "\nType the number to vote! (or -poll <number>). Poll closes in 5 minutes.";

  return ({
    param   => "message",
    message => $message,
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub poll_vote {
  my ($user, $choice) = @_;

  if (!$DCBCommon::COMMON->{poll} || !$DCBCommon::COMMON->{poll}->{active}) {
    return ({
      param   => "message",
      message => "No active poll. Use -poll create to start one.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $poll = $DCBCommon::COMMON->{poll};

  if ($choice < 1 || $choice > scalar(@{$poll->{options}})) {
    return ({
      param   => "message",
      message => "Invalid choice. Pick 1-" . scalar(@{$poll->{options}}),
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  if ($poll->{voters}->{$user->{uid}}) {
    return ({
      param   => "message",
      message => "You already voted!",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  $poll->{votes}->{$choice}++;
  $poll->{voters}->{$user->{uid}} = $choice;

  return ({
    param   => "message",
    message => "$user->{name} voted! (" . scalar(keys %{$poll->{voters}}) . " total votes)",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub poll_end {
  my ($user) = @_;

  if (!$DCBCommon::COMMON->{poll} || !$DCBCommon::COMMON->{poll}->{active}) {
    return ({
      param   => "message",
      message => "No active poll.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $poll = $DCBCommon::COMMON->{poll};
  if ($user->{uid} != $poll->{creator} && !DCBUser::user_is_admin($user)) {
    return ({
      param   => "message",
      message => "Only the poll creator or an operator can close it.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  return poll_finalize();
}

sub poll_finalize {
  my $poll = $DCBCommon::COMMON->{poll};
  my $total_votes = scalar(keys %{$poll->{voters}});

  my $message = "*** POLL RESULTS ***\n$poll->{question}\n\n";

  # Find winner
  my $max_votes = 0;
  my $winner_idx = 0;
  foreach my $idx (sort { $a <=> $b } keys %{$poll->{votes}}) {
    my $count = $poll->{votes}->{$idx};
    my $pct = $total_votes > 0 ? int(($count / $total_votes) * 100) : 0;
    my $bar_len = $total_votes > 0 ? int(($count / $total_votes) * 20) : 0;
    my $bar = '|' x $bar_len . '.' x (20 - $bar_len);
    my $option = $poll->{options}->[$idx - 1];
    $message .= "  $idx) $option: [$bar] $count votes (${pct}%)\n";
    if ($count > $max_votes) {
      $max_votes = $count;
      $winner_idx = $idx;
    }
  }

  if ($total_votes > 0) {
    $message .= "\nWinner: $poll->{options}->[$winner_idx - 1] with $max_votes votes!";
  }
  else {
    $message .= "\nNo votes were cast.";
  }
  $message .= " ($total_votes total votes)";

  $DCBCommon::COMMON->{poll} = { active => 0 };

  return ({
    param   => "message",
    message => $message,
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub poll_status {
  my ($user) = @_;

  if (!$DCBCommon::COMMON->{poll} || !$DCBCommon::COMMON->{poll}->{active}) {
    return ({
      param   => "message",
      message => "No active poll.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $poll = $DCBCommon::COMMON->{poll};
  my $total = scalar(keys %{$poll->{voters}});
  my $elapsed = int((time() - $poll->{time}) / 60);
  my $remaining = 5 - $elapsed;
  $remaining = 0 if $remaining < 0;

  my $message = "*** ACTIVE POLL ($total votes, ${remaining}min remaining) ***\n$poll->{question}\n\n";
  foreach my $idx (sort { $a <=> $b } keys %{$poll->{votes}}) {
    my $option = $poll->{options}->[$idx - 1];
    $message .= "  $idx) $option: $poll->{votes}->{$idx} votes\n";
  }

  my $voted = $poll->{voters}->{$user->{uid}} ? "You voted for #$poll->{voters}->{$user->{uid}}" : "You haven't voted yet!";
  $message .= "\n$voted";

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub poll_help {
  my ($user) = @_;
  return ({
    param   => "message",
    message => "*** POLL COMMANDS ***\n-poll create Question? | Option 1 | Option 2 | Option 3\n-poll <number> - Vote\n-poll status - See current results\n-poll end - Close the poll\n\nPolls auto-close after 5 minutes. Just type the number to vote!",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

1;
