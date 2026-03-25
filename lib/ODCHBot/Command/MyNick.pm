package ODCHBot::Command::MyNick;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'mynick',
    description => 'Display your own nickname',
    usage       => 'mynick',
}}

sub execute {
    my ($self, $ctx) = @_;
    $ctx->reply("Your nick is: " . $ctx->user->name);
}

1;
