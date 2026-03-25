package ODCHBot::Command::Search;
use Moo;
use ODCHBot::Formatter qw(format_timestamp);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'search',
    description => 'Search chat history',
    usage       => 'search <query> (min 5 characters)',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $query = $ctx->args;

    unless ($query && length($query) >= 5) {
        $ctx->reply("Search query must be at least 5 characters.");
        return;
    }

    # Escape SQL wildcards in user input
    my $safe = $query;
    $safe =~ s/%/\\%/g;
    $safe =~ s/_/\\_/g;

    my $tz = $self->config->get('timezone') // 'UTC';

    my $rows = $self->db->dbh->selectall_arrayref(
        "SELECT * FROM history WHERE chat LIKE ? ESCAPE '\\' ORDER BY hid DESC LIMIT 50",
        { Slice => {} },
        "%$safe%"
    );

    unless (@$rows) {
        $ctx->reply("No results found for '$query'.");
        return;
    }

    my $msg = "\nSearch results for '$query' (" . scalar(@$rows) . " found):\n";
    my %user_cache;

    for my $row (@$rows) {
        $user_cache{$row->{uid}} //= $self->users->find_by_uid($row->{uid});
        my $user = $user_cache{$row->{uid}};
        my $name = $user ? $user->name : 'Unknown';
        my $time = format_timestamp($row->{time}, $tz);
        $msg .= "[$time] <$name> $row->{chat}\n";
    }

    $ctx->reply($msg);
}

1;
