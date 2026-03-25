package ODCHBot::Command::Bug;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'bug',
    description => 'Submit a bug report to GitHub',
    usage       => 'bug <description>',
    permission  => ODCHBot::User::PERM_AUTHENTICATED,
}}

sub config_defaults {{
    bug_github_url  => 'https://api.github.com/repos',
    bug_github_user => '',
    bug_github_repo => '',
    bug_github_key  => '',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $report = $ctx->args;

    unless (length($report // '')) {
        $ctx->reply("Usage: bug <description>");
        return;
    }

    my $message = "Submitting bug report\n";

    my $url   = $self->config->get('bug_github_url')  // 'https://api.github.com/repos';
    my $owner = $self->config->get('bug_github_user') // '';
    my $repo  = $self->config->get('bug_github_repo') // '';
    my $token = $self->config->get('bug_github_key')  // '';

    if ($token && $owner && $repo) {
        require HTTP::Request;
        require LWP::UserAgent;
        require JSON;

        my $api_url = "$url/$owner/$repo/issues";
        my $ua  = LWP::UserAgent->new(timeout => 10);
        my $req = HTTP::Request->new(POST => $api_url);
        $req->content(JSON::encode_json({ title => $report, body => $report }));
        $req->header('Authorization' => "bearer $token");
        $req->header('Content-Type'  => 'application/json');

        my $res = $ua->request($req);
        if ($res->is_success) {
            my $data = JSON::decode_json($res->content);
            $message .= "Github issue created here => " . ($data->{html_url} // 'unknown');
        }
        else {
            $message .= "GitHub API error: " . $res->status_line;
        }
    }
    else {
        $message .= "Github token not set, cannot auto-create issue.";
    }

    # Optional email notification
    if (eval { require Mail::Sendmail; 1 }) {
        require Sys::Hostname;
        my $hostname = Sys::Hostname::hostname();
        my $to = $self->config->get('maintainer_email');
        if ($to) {
            my %mail = (
                To      => $to,
                From    => "bug_report\@$hostname",
                Subject => "[BUG REPORT] (" . ($self->config->get('botname') // 'ODCHBot') . ")",
                Message => "Submitted by: " . $ctx->user->name . "\nHost: $hostname\nBug Report: $report",
            );
            if (Mail::Sendmail::sendmail(%mail)) {
                $message .= "\nBug report successfully emailed!";
            }
            else {
                $message .= "\n" . $Mail::Sendmail::error;
            }
        }
    }

    $ctx->reply_public($message);
}

1;
