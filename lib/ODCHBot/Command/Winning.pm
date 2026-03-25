package ODCHBot::Command::Winning;
use Moo;
use ODCHBot::Formatter qw(format_duration_short);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'winning',
    description => 'Show users with the longest online time',
    usage       => 'winning [count]',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $count = int($ctx->args || 10);
    $count = 50 if $count > 50;
    $count = 1  if $count < 1;

    my @online = sort {
        ($b->connect_time // 0) <=> ($a->connect_time // 0)
    } $self->users->online_users;

    # Actually sort by duration (longest first = earliest connect time)
    @online = sort {
        ($a->connect_time // time()) <=> ($b->connect_time // time())
    } @online;

    splice @online, $count if @online > $count;

    my $msg = "\nLongest Connected Users:\n";
    my $i = 1;
    for my $user (@online) {
        my $dur = format_duration_short($user->online_duration);
        $msg .= sprintf("%2d. %-20s %s\n", $i++, $user->name, $dur);
    }

    $msg .= "No users online.\n" unless @online;
    $ctx->reply($msg);
}

1;
