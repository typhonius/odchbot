package update;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBSettings;
use IPC::System::Simple qw(capture);

sub main {
  my $command = shift;
  my $user = shift;
  my $output = '';
  $output = capture("cd $DCBSettings::cwd ; git pull origin $DCBSettings::config->{version} ; " . 'git log @{1}..  --oneline');
  chomp($output);
  my @return = ();

  @return = (
    {
      param    => "message",
      message  => "$output",
      user     => $user->{name},
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

1;
