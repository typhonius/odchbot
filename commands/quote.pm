package quote;

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
      quotes => {
        qid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        uid      => { type => "INTEGER" },
        quote    => { type => "BLOB" },
        added_by => { type => "INTEGER" },
        time     => { type => "INT" },
      },
    }),
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift || '';
  my @return = ();

  my @args = split(/\s+/, $chat, 2);
  my $action = lc($args[0] || 'random');
  my $rest = $args[1] || '';

  if ($action eq 'add' && $rest) {
    @return = quote_add($user, $rest);
  }
  elsif ($action eq 'del' || $action eq 'delete') {
    @return = quote_delete($user, $rest);
  }
  elsif ($action eq 'search' && $rest) {
    @return = quote_search($user, $rest);
  }
  elsif ($action eq 'count') {
    @return = quote_count($user);
  }
  elsif ($action =~ /^\d+$/) {
    @return = quote_by_id($user, $action);
  }
  elsif ($action eq 'random' || $action eq '') {
    @return = quote_random($user);
  }
  else {
    @return = quote_help($user);
  }

  return @return;
}

sub quote_add {
  my ($user, $text) = @_;

  my %fields = (
    'uid'      => $user->{uid},
    'quote'    => $text,
    'added_by' => $user->{uid},
    'time'     => time(),
  );
  DCBDatabase::db_insert('quotes', \%fields);

  return ({
    param   => "message",
    message => "Quote saved by $user->{name}!",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub quote_delete {
  my ($user, $qid) = @_;

  if (!DCBUser::user_is_admin($user)) {
    return ({
      param   => "message",
      message => "Only operators can delete quotes.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  if ($qid =~ /^\d+$/) {
    my %where = ('qid' => $qid);
    DCBDatabase::db_delete('quotes', \%where);
    return ({
      param   => "message",
      message => "Quote #$qid deleted.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  return ({
    param   => "message",
    message => "Usage: -quote del [id]",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub quote_random {
  my ($user) = @_;

  # Get count first
  my $counth = DCBDatabase::db_select('quotes', ['qid']);
  my @all_ids = ();
  while (my $row = $counth->fetchrow_hashref()) {
    push(@all_ids, $row->{qid});
  }

  if (!@all_ids) {
    return ({
      param   => "message",
      message => "No quotes saved yet! Use -quote add <text> to add one.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $random_qid = $all_ids[int(rand(scalar @all_ids))];
  return quote_by_id($user, $random_qid);
}

sub quote_by_id {
  my ($user, $qid) = @_;

  my @fields = ('*');
  my %where = ('qid' => $qid);
  my $sth = DCBDatabase::db_select('quotes', \@fields, \%where);
  my $row = $sth->fetchrow_hashref();

  if (!$row) {
    return ({
      param   => "message",
      message => "Quote #$qid not found.",
      user    => $user->{name},
      touser  => '',
      type    => MESSAGE->{'PUBLIC_SINGLE'},
    });
  }

  my $added_user = DCBUser::user_load($row->{added_by});
  my $added_name = $added_user ? $added_user->{name} : 'Unknown';
  my $time_str = DCBCommon::common_timestamp_time($row->{time});

  return ({
    param   => "message",
    message => "Quote #$row->{qid}: \"$row->{quote}\" (added by $added_name, $time_str)",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
}

sub quote_search {
  my ($user, $term) = @_;

  my %where = ('quote' => { -like => ["%$term%"] });
  my @fields = ('qid', 'quote');
  my $sth = DCBDatabase::db_select('quotes', \@fields, \%where, {}, 10);

  my $message = "*** Quote Search: '$term' ***\n";
  my $found = 0;
  while (my $row = $sth->fetchrow_hashref()) {
    $found++;
    my $snippet = substr($row->{quote}, 0, 80);
    $message .= "#$row->{qid}: \"$snippet\"\n";
  }

  if (!$found) {
    $message .= "No quotes found.";
  }

  return ({
    param   => "message",
    message => $message,
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub quote_count {
  my ($user) = @_;

  my $sth = DCBDatabase::db_select('quotes', ['qid']);
  my $count = 0;
  while ($sth->fetchrow_array()) { $count++; }

  return ({
    param   => "message",
    message => "There are $count quotes in the database.",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

sub quote_help {
  my ($user) = @_;
  return ({
    param   => "message",
    message => "*** QUOTE COMMANDS ***\n-quote - Show a random quote\n-quote add <text> - Save a new quote\n-quote [id] - Show a specific quote\n-quote search <term> - Search quotes\n-quote count - How many quotes\n-quote del [id] - Delete a quote (ops only)",
    user    => $user->{name},
    touser  => '',
    type    => MESSAGE->{'PUBLIC_SINGLE'},
  });
}

1;
