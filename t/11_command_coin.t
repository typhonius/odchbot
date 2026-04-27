use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../commands";
use lib "$FindBin::Bin/lib";
use MockODCH;

use DCBSettings;
$DCBSettings::config = {
    timezone => 'UTC',
};

use DCBCommon;
use coin;

my $test_user = { uid => 1, name => 'TestUser', permission => 4 };

# ---- Test basic coin flip (no args) ----
my @result = coin::main(undef, $test_user, '');
is( scalar @result, 1, 'Coin flip returns one action' );
is( $result[0]->{param}, 'message', 'Action is a message' );
is( $result[0]->{type}, MESSAGE->{'PUBLIC_ALL'}, 'Message type is PUBLIC_ALL' );
like( $result[0]->{message}, qr/^(Heads|Tails)$/, 'Result is Heads or Tails' );

# ---- Test yes/no question ----
@result = coin::main(undef, $test_user, 'Should I stay');
is( scalar @result, 1, 'Question returns one action' );
like( $result[0]->{message}, qr/The answer to 'Should I stay' is (yes|no)/, 'Yes/no answer format' );

# ---- Test "or" decision ----
@result = coin::main(undef, $test_user, 'pizza or burger');
is( scalar @result, 1, 'Or-decision returns one action' );
like( $result[0]->{message}, qr/The answer to 'pizza or burger' is (pizza|burger)/, 'Picks one of the options' );

# ---- Test multiple "or" options ----
@result = coin::main(undef, $test_user, 'red or blue or green');
is( scalar @result, 1, 'Multi-or returns one action' );
like( $result[0]->{message}, qr/The answer to 'red or blue or green' is (red|blue|green)/, 'Picks from multiple options' );

# ---- Test consistency: always returns exactly one message ----
for my $i (1..10) {
    @result = coin::main(undef, $test_user, '');
    is( scalar @result, 1, "Iteration $i returns exactly one result" );
    ok( defined $result[0]->{message}, "Iteration $i has a message" );
}

done_testing;
