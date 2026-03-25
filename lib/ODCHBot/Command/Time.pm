package ODCHBot::Command::Time;
use Moo;
use Scalar::Util qw(looks_like_number);
use ODCHBot::Formatter qw(format_timestamp);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'time',
    description => 'Show the current time',
    usage       => 'time [epoch]',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $tz    = $self->config->get('timezone') // 'UTC';
    my $epoch = $ctx->args;

    if ($epoch && looks_like_number($epoch)) {
        $ctx->reply(format_timestamp($epoch, $tz));
    }
    else {
        $ctx->reply(format_timestamp(time(), $tz));
    }
}

1;
