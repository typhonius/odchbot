package ODCHBot::Command::MagicEightBall;
use Moo;
with 'ODCHBot::Role::Command';

my @ANSWERS = (
    'As I see it, yes',
    'Ask again later',
    'Better not tell you now',
    'Cannot predict now',
    'Concentrate and ask again',
    'Definitely',
    'Don\'t count on it',
    'It is certain',
    'It is decidedly so',
    'Most likely',
    'My reply is no',
    'My sources say no',
    'Outlook good',
    'Outlook not so good',
    'Reply hazy, try again',
    'Signs point to yes',
    'Very doubtful',
    'Without a doubt',
    'Yes',
    'You may rely on it',
);

sub meta_info {{
    name        => 'magic_8ball',
    description => 'Ask the Magic 8 Ball a question',
    usage       => '8ball <question>',
    aliases     => ['8ball'],
}}

sub execute {
    my ($self, $ctx) = @_;
    $ctx->reply_hub($ANSWERS[rand @ANSWERS]);
}

1;
