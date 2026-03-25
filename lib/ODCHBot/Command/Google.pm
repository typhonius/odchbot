package ODCHBot::Command::Google;
use Moo;
use URI::Escape qw(uri_escape);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'google',
    description => 'Generate a Google search link',
    usage       => 'google <query>',
    aliases     => ['g'],
}}

sub execute {
    my ($self, $ctx) = @_;
    my $query = $ctx->args;

    unless (length $query) {
        $ctx->reply("Usage: google <query>");
        return;
    }

    my $url = 'https://www.google.com/search?q=' . uri_escape($query);
    $ctx->reply_hub("Google: $url");
}

1;
