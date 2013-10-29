package help;
 
use strict;
use warnings;
use FindBin;
use DCBCommon;
use lib "$FindBin::Bin/..";
 
sub main {
  my $command = shift;
  my $user = shift;
 
  my @return = ();
  my $message = "";
  my $hub_name = DCBSettings::config_get('hubname');
  my $hub_href = DCBSettings::config_get('website');
 
  $message = "Welcome to " . $hub_name . " Displaying help and tips!\n";
  $message .= "If you are having connection issues, try the following steps in order:\n";
  $message .= "1. Make sure you are running the client as Administrator.\n";
  $message .= "2. Make sure you are not connecting through a wireless connection or using a router.\n";
  $message .= "3. Refresh your IP address and restart the client.\n";
  $message .= "4. In your connection settings, make sure you are using \'Direct connection\'.\n";
  $message .= "5. Check your firewall settings to ensure it allows the DC client you're running through.\n";
  $message .= "6. Restart your your client and try to connect again and check to see if the problem has been fixed.\n";
  $message .= "Detailed guides are for help with these steps are available on the website, " . $hub_href . "/\n";
  $message .= "If you are still having issues, please contact us through chat or email and make sure to include ANY messages ChaosBot is sending you, in full.\n";
 
  @return = (
    {
      param    => "message",
      message  => "$message",
      user     => $user->{'name'},
      touser   => '',
      type     => MESSAGE->{PUBLIC_SINGLE},
    },
  );
  return @return;
}
 
1;
