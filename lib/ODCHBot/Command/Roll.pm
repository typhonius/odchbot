package ODCHBot::Command::Roll;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'roll',
    description => 'Roll dice in NdS notation',
    usage       => 'roll [NdS] (e.g., roll 2d20, roll d6, roll 4d8+2)',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $input = $ctx->args || '1d6';

    my ($num, $sides, $mod) = $input =~ /^(\d*)d(\d+)(?:\+(\d+))?$/i;
    unless (defined $sides) {
        $ctx->reply("Usage: roll NdS (e.g., 2d20, d6, 4d8+2)");
        return;
    }

    $num ||= 1;
    $mod ||= 0;

    if ($num < 1 || $num > 100) {
        $ctx->reply("Number of dice must be between 1 and 100");
        return;
    }
    if ($sides < 2 || $sides > 1000) {
        $ctx->reply("Sides must be between 2 and 1000");
        return;
    }

    my @rolls;
    my $total = 0;
    for (1 .. $num) {
        my $roll = int(rand($sides)) + 1;
        push @rolls, $roll;
        $total += $roll;
    }
    $total += $mod;

    my $result = join(', ', @rolls);
    $result .= " + $mod" if $mod;
    $result .= " = $total" if $num > 1 || $mod;

    $ctx->reply_hub("Rolling ${num}d${sides}" . ($mod ? "+$mod" : '') . ": $result");
}

1;
