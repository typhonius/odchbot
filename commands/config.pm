package config;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use YAML::AppConfig;
use DCBSettings;
use DCBCommon;

# Config keys that cannot be modified or viewed via chat commands
my @PROTECTED_KEYS = qw(db jabber commandPath bug_github_key);

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my @return = ();

  my $message = "Incorrect/invalid config key";
  my $yaml;
  eval { $yaml = YAML::AppConfig->new( file => $DCBSettings::cwd . 'odchbot.yml' ); };
  if ($@) {
    $message = "Failed to load config file: $@";
    my @return = ({ param => "message", message => $message, user => $user->{name}, touser => '', type => MESSAGE->{'PUBLIC_SINGLE'} });
    return @return;
  }
  my $conf = $DCBSettings::config;

  # Put the chat into an array and remove the first word (the flag of get/set)
  my @chatarray = split(/\s+/, $chat);
  my $op = shift(@chatarray);
  my $variable = shift(@chatarray);
  my $value = join(' ', @chatarray);
  if ($op) {
    if ($op =~ /^get$/) {
      if (grep { $_ eq $variable } @PROTECTED_KEYS) {
        $message = "Cannot view protected config key: $variable";
      }
      elsif (defined(my $var = DCBSettings::config_get($variable))) {
        $message = "$var";
      }
    }
    elsif ($op =~ /^set$/) {
      if (grep { $_ eq $variable } @PROTECTED_KEYS) {
        $message = "Cannot modify protected config key: $variable";
      }
      elsif (DCBSettings::config_set($variable, $value)) {
        $message = "$variable set to $value";
      }
    }
    elsif ($op =~ /^delete$/) {
      if (grep { $_ eq $variable } @PROTECTED_KEYS) {
        $message = "Cannot delete protected config key: $variable";
      }
      elsif (DCBSettings::config_delete($variable)) {
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
    my $dump = $yaml->dump();
    # Redact sensitive values from the dump
    $dump =~ s/(password|key|secret|token):\s*.+/$1: [REDACTED]/gi;
    $message .= $dump;
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
      type     => MESSAGE->{'PUBLIC_SINGLE'},
      #sanitize => $sanitize,
    },
  );
  return @return;
}

1;
