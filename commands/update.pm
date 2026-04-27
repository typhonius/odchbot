package update;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use IPC::System::Simple qw(capture);
use DCBSettings;
use DCBCommon;
use Cwd;

sub main {
  my $command = shift;
  my $user = shift;
  my $output = '';
  # Use list form to prevent shell injection via config values
  my $old_dir = Cwd::getcwd();
  eval {
    chdir($DCBSettings::cwd) or die "Cannot chdir to $DCBSettings::cwd: $!";
    $output = capture("git", "pull");
  };
  if ($@) {
    $output = "Update failed: $@";
  }
  chdir($old_dir) if $old_dir;
  # temporarily removing the git log from the output as first time clones will not be able to run it
  #; " . 'git log @{1}..  --oneline');
  chomp($output);
  my @return = ();

  @return = (
    {
      param    => "message",
      message  => "$output",
      user     => $user->{name},
      touser   => '',
      type     => MESSAGE->{'PUBLIC_ALL'},
    },
  );
  return @return;
}

1;
