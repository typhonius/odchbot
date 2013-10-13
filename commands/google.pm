#Written by Wickfish May 2013 for Chaotic Neutral
package google;

use strict;
use warnings;
use Switch;
use FindBin;
use lib "$FindBin::Bin/..";

sub main{
  my $command = shift;
  my $user = shift;
  my $chat = shift;
  
  my $message = '';
  my @return = ();
  my @args = split(/\s/,$chat);
  my $argNo = scalar(@args);
  
  if ($argNo > 10) {
    $message = "Too many search parameters. Try a something shorter. Or, you know, just open a web browser.";
  } else {
    $message = "http://www.google.com/search?q=";
    foreach (@args) {
	  $message .= $_ . "+";
	  }
  }
  
  
@return = (
    {
      param    => "message",
      message  => $message,
      user     => '',
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

1;
