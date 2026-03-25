package ODCHBot::Command::Quote;
use Moo;
use ODCHBot::Formatter qw(format_timestamp);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'quote',
    description => 'Show a random quote from chat history',
    usage       => 'quote [username]',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $name = $ctx->args;
    my $tz   = $self->config->get('timezone') // 'UTC';

    my $where = {};
    if ($name) {
        my $target = $self->users->find_by_name($name);
        unless ($target) {
            $ctx->reply("User '$name' not found.");
            return;
        }
        $where->{uid} = $target->uid;
    }

    my $rows = $self->db->do_sql(
        "SELECT * FROM history" .
        (keys %$where ? " WHERE uid = ?" : '') .
        " ORDER BY RANDOM() LIMIT 1",
        keys %$where ? values %$where : ()
    );

    # Use select and pick random since do_sql doesn't return rows easily
    my $all = $self->db->select('history', '*', $where);
    unless (@$all) {
        $ctx->reply($name ? "No quotes found for $name." : "No chat history found.");
        return;
    }

    my $quote = $all->[rand @$all];
    my $user  = $self->users->find_by_uid($quote->{uid});
    my $who   = $user ? $user->name : 'Unknown';
    my $time  = format_timestamp($quote->{time}, $tz);

    $ctx->reply("[$time] <$who> $quote->{chat}");
}

1;
