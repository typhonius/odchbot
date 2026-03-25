package ODCHBot::Command::First;
use Moo;
use ODCHBot::Formatter qw(format_timestamp);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'first',
    description => 'Show the first line spoken by a user',
    usage       => 'first <username>',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args || $ctx->user->name;
    my $tz   = $self->config->get('timezone') // 'UTC';

    my $target = $self->users->find_by_name($name);
    unless ($target) {
        $ctx->reply("User '$name' does not exist.");
        return;
    }

    my $rows = $self->db->select('history', '*', { uid => $target->uid }, { -asc => 'hid' });
    my $first = $rows->[0];

    if ($first) {
        my $time = format_timestamp($first->{time}, $tz);
        $ctx->reply("First line spoken by " . $target->name . ":\n[$time] <" . $target->name . ">: $first->{chat}");
    }
    else {
        $ctx->reply($target->name . " has never spoken; boring!");
    }
}

1;
