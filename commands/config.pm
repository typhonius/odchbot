package config;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use Switch;
use YAML::AppConfig;
use DCBSettings;

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();

  my $message = "Incorrect/invalid config key";
  my $yaml = YAML::AppConfig->new( file => $DCBSettings::cwd . 'odchbot.yml' );
  my $conf = $DCBSettings::config;

  # Put the chat into an array and remove the first word (the flag of get/set)
  my @chatarray = split(/\s+/, $chat);
  my $op = shift(@chatarray);
  my $variable = shift(@chatarray);
  my $value = join(' ', @chatarray);
  if ($op) {
    if ($op =~ /^get$/) {
      if (my $var = DCBSettings::config_get($variable)) {
        $message = $var;
      }
    }
    elsif ($op =~ /^set$/) {
      # TODO put in message confirmation here.
      if (DCBSettings::config_set($variable, $value)) {
        $message = "$variable set to $value";
      }
    }
    elsif ($op =~ /^delete$/) {
      if (DCBSettings::config_delete($variable)) {
        $message = "$variable deleted";
      }
    }
    elsif ($op =~ /^reload$/) {
      # Straight up reload the config from the conf file and replace whatever
      # is currently there with whatever is in the conf file.
      if (DCBSettings::config_reload()) {
        $message = "Config reloaded!";
      }
    }
  }
  else {
    $message = "Bot Configuration\n";
    $message .= $yaml->dump();
    $message =~ s/ / &#8203;/g;
  }


  # Show indentation with hyphens in case client strips spaces
  #$message =~ s/^\s\w/\-/g;
  #$message =~ s/\r?\n/\r\n/g;
  #$message =~ s/\|//g;  
  #our $config   = $yaml->get('config');
  @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => 2,
      #sanitize => $sanitize,
    },
  );
  return @return;
}

1;
