package ODCHBot::Command::Haha;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'haha',
    description => 'Feeling lucky? 1 in 6 chance of getting kicked',
    usage       => 'haha',
}}

sub execute {
    my ($self, $ctx) = @_;

    if (int(rand(6)) == 0) {
        $ctx->reply_hub("HAHA! " . $ctx->user->name . " loses!");
        $ctx->kick($ctx->user, "HAHAHA!");
    }
    else {
        $ctx->reply_hub($ctx->user->name . " got lucky this time!");
    }
}

1;
