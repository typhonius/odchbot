package ODCHBot::Command::RussianRoulette;
use Moo;
with 'ODCHBot::Role::Command';

has _barrel => (is => 'rw', default => sub { int(rand(6)) + 1 });

sub meta_info {{
    name        => 'russianroulette',
    description => 'Spin the barrel and pull the trigger',
    usage       => 'rr',
    aliases     => ['rr'],
}}

sub execute {
    my ($self, $ctx) = @_;

    my $pos = $self->_barrel;
    $self->_barrel($pos - 1);

    if ($pos <= 1) {
        $ctx->reply_hub("*BANG* " . $ctx->user->name . " is dead!");
        $ctx->kick($ctx->user, "Russian Roulette - BANG!");
        $self->_barrel(int(rand(6)) + 1);  # Reload
    }
    else {
        $ctx->reply_hub("*click* " . $ctx->user->name . " got lucky... " . ($pos - 1) . " chambers left.");
    }
}

1;
