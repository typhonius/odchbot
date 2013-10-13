package bug;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use Sys::Hostname;
use Mail::Sendmail;
use HTTP::Request;
use LWP::UserAgent;
use JSON qw( decode_json );

sub schema {
  my %schema = (
    config => {
      bug_github_url => 'https://api.github.com/repos',
      bug_github_user => 'odchbot',
      bug_github_repo => 'odchbot',
      bug_github_key => '',
    },
  );
  return \%schema;
}

sub main {
  my $command = shift;
  my $user = shift;
  my $chat = shift;

  my $message = "Submitting bug report\n";

  my $url = DCBSettings::config_get('bug_github_url');
  $url .= "/" . DCBSettings::config_get('bug_github_user');
  $url .= "/" . DCBSettings::config_get('bug_github_repo');
  $url .= "/issues";

  my $token = DCBSettings::config_get('bug_github_key');

  if ($token) {
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(POST => $url);
    my $post_data = '{ "title": "' . $chat . '", "body": "' . $chat . '" }';
    $req->content($post_data);
    $req->header('Authorization' => "bearer " . $token);
    my $res = $ua->request($req);

    if ($res->is_success) {
      my $response = decode_json($res->content);
      $message .= "Github issue created here => " . $response->{'html_url'};;
    }
    else {
      $message .= $res->content;
    }
  }
  else {
    $message .= "Github token not set, cannot auto-create issue.";
  }

  my $hostname = hostname;
  my %mail = ( To      => $DCBSettings::config->{maintainer_email},
            From    => "bug_report@" . $hostname,
            Subject => "[BUG REPORT] ($DCBSettings::config->{botname})",
            Message => "Submitted by: $user->{name}\nHost: $hostname\nBug Report: $chat",
          );

  if (sendmail(%mail)) {
    $message .= "\nBug report successfully emailed! Thanks~~ :3";
  }
  else {
    $message .= "\n\n" . $Mail::Sendmail::error;
  }

  my @return = (
    {
      param    => "message",
      message  => $message,
      user     => $user->{name},
      touser   => '',
      type     => 4,
    },
  );
  return @return;
}

1;
