package toggle;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;
use DCBDatabase;

sub main {
  my $command = shift;
  my $user = shift;
  my @chatarray = split(/\s+/, shift);
  my $togglecommand = @chatarray ? shift(@chatarray) : '';
  my $status = @chatarray ? shift(@chatarray) : '';
  my $message = 'Could not set status';

  if ($togglecommand && $DCBCommon::registry->{commands}->{$togglecommand} && ($status || $status =~ 0)) {
    $DCBCommon::registry->{commands}->{$togglecommand}->{status} = $status;
    my %fields = (
    'status' => $status,
    );
    my %where = ('name' => $togglecommand);
    DCBDatabase::db_update('registry', \%fields, \%where);
    $message = "Set status of $togglecommand to $status";
  }

  my @return = ();

  @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

sub alter {
  my ($command, $hook, $user, $params) = @_;

  return ($command, $hook, $user, $params);
}

1;
