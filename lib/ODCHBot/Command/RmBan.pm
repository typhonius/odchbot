package ODCHBot::Command::RmBan;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'rmban',
    description => 'Remove a ban from a user',
    usage       => 'rmban <username>',
    permission  => ODCHBot::User::PERM_OPERATOR,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: rmban <username>");
        return;
    }

    my $victim = $self->users->find_by_name($name);
    unless ($victim) {
        $ctx->reply("User '$name' not found.");
        return;
    }

    my $deleted = $self->db->delete_rows('ban', { uid => $victim->uid });
    $ctx->unban($victim);
    $ctx->reply("Ban removed for $name");
}

1;
