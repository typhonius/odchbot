package ODCHBot::Command::Unwatch;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'unwatch',
    description => 'Stop watching a user',
    usage       => 'unwatch <username>',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;

    unless ($name) {
        $ctx->reply("Usage: unwatch <username>");
        return;
    }

    my $target = $self->users->find_by_name($name);
    unless ($target) {
        $ctx->reply("User '$name' not found.");
        return;
    }

    my $deleted = $self->db->delete_rows('watch', {
        uid         => $ctx->user->uid,
        watched_uid => $target->uid,
    });

    $ctx->reply("Stopped watching $name");
}

1;
