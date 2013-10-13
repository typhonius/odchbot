package say;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBUser;

sub main {
  my $command = shift;
  my $user = shift;

  my @return = ();

  @return = (
    {
      param    => "message",
      message  => "Nice try $user->{name} - no using say here!",
      user     => '',
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

sub line {
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  my @return = ();

  if ($chat =~ /^!say\s(\w+)\s(.*)/ && user_access($user, DCBUser::PERMISSIONS->{ADMINISTRATOR})) {
    @return = (
      {
        param    => "message",
        message  => $2,
        user     => $1,
        fromuser => '',
        type     => 10,
      },
      {
        param    => "message",
        message  => "$user->{name} just used !say => $chat",
        user     => '',
        fromuser => '',
        type     => 7,
      }
    );
  }

  return @return;
}

1;