package winning;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw(min);
use Scalar::Util qw(looks_like_number);
use DCBSettings;
use DCBDatabase;
use DCBUser;

sub schema {
  my %schema = (
    config => {
      winning_default => 10,
      winning_max => 100,
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $limit = shift;
  
  $limit = looks_like_number($limit) ? min $limit, $DCBSettings::config->{'winning_max'} : $DCBSettings::config->{'winning_default'}; 

  my @return = ();

  my %winners = ();
  foreach my $this_user (keys %{$DCBUser::userlist}) {
    $this_user = lc($this_user);
    if ($DCBUser::userlist->{$this_user}->{'join_time'}) {
      if ($DCBUser::userlist->{$this_user}->{'connect_time'} > $DCBUser::userlist->{$this_user}->{'disconnect_time'}) {
        $winners{$this_user} = $DCBUser::userlist->{$this_user}->{'connect_time'};
      }
    }
  }
  my $winners = "List of longest logged in users:\n";
  foreach my $key (sort {$winners{$a} cmp $winners{$b}} keys %winners){
    if ($limit) {
      $winners .= "$key: " . DCBCommon::common_timestamp_duration($winners{$key}) . "\n";
      $limit--;
    }
  }
  @return = (
    {
      param    => "message",
      message  => $winners,
      user     => $user->{name},
      touser   => '',
      type     => 2,
    },
  );
  return @return;
}

1;
