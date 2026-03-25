package ODCHBot::Command::Last;
use Moo;
use ODCHBot::Formatter qw(format_timestamp);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'last',
    description => 'Show the last line spoken by a user',
    usage       => 'last <username>',
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

    my $rows = $self->db->select('history', '*', { uid => $target->uid }, { -desc => 'hid' });
    my $last = $rows->[0];

    if ($last) {
        my $time = format_timestamp($last->{time}, $tz);
        $ctx->reply("Last line spoken by " . $target->name . ":\n[$time] <" . $target->name . ">: $last->{chat}");
    }
    else {
        $ctx->reply($target->name . " has never spoken; boring!");
    }
}

1;
