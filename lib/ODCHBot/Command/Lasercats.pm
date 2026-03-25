package ODCHBot::Command::Lasercats;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'lasercats',
    description => 'PEW PEW PEW!',
    usage       => 'lasercats <username>',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("PEW PEW PEW! (Usage: lasercats <username>)");
        return;
    }

    my $victim = $self->users->find_by_name($name);
    unless ($victim && $victim->is_online) {
        $ctx->reply("$name is not here to be zapped!");
        return;
    }

    $ctx->reply_hub("PEW PEW PEW! " . $ctx->user->name . " fires lasercats at $name!");
    $ctx->kick($victim, "LASERCATS! PEW PEW PEW!");
}

1;
