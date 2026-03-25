package ODCHBot::Command::TV;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'tv',
    description => 'TV show information (coming soon)',
    usage       => 'tv',
}}

sub execute {
    my ($self, $ctx) = @_;
    $ctx->reply_public("This will return the TV command");
}

1;
