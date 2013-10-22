package say;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;
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
      type     => MESSAGE->{'PUBLIC_ALL'},
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
        type     => MESSAGE->{'SPOOF_PUBLIC'},
      },
      {
        param    => "message",
        message  => "$user->{name} just used !say => $chat",
        user     => '',
        fromuser => '',
        type     => MESSAGE->{'SEND_TO_OPS'},
      }
    );
  }

  return @return;
}

1;