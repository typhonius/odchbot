package ODCHBot::Command::Coin;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'coin',
    description => 'Flip a coin or decide between options',
    usage       => 'coin [option1 or option2 or ...]',
    aliases     => ['flip'],
}}

sub execute {
    my ($self, $ctx) = @_;
    my $text = $ctx->args;

    if (length($text) && $text =~ /\sor\s/) {
        my @options = split /\s+or\s+/, $text;
        my $pick = $options[rand @options];
        $ctx->reply_hub("The answer to '$text' is $pick");
    }
    elsif (length($text)) {
        my @yesno = ('yes', 'no');
        $ctx->reply_hub("The answer to '$text' is " . $yesno[rand 2]);
    }
    else {
        $ctx->reply_hub(rand(2) < 1 ? 'Heads' : 'Tails');
    }
}

1;
