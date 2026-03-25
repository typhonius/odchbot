package ODCHBot::Command::Karma;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'karma',
    description => 'View karma info or see ++/-- in chat',
    usage       => 'karma',
    hooks       => ['line'],
}}

sub execute {
    my ($self, $ctx) = @_;
    my $url = $self->config->get('web_karma') // '';
    if ($url) {
        $ctx->reply("Karma: $url");
    }
    else {
        $ctx->reply("Use <name>++ or <name>-- in chat to give karma!");
    }
}

sub on_line {
    my ($self, $data) = @_;
    my $user = $data->{user} or return;
    my $chat = $data->{chat} // '';

    if ($chat =~ /^(\S+)\+\+/) {
        my $target = $1;
        return if lc($target) eq lc($user->name);  # No self-karma
        my $ctx = ODCHBot::Context->new(user => $user, bot => $self->bot);
        $ctx->reply_hub("$target has received a karma point from " . $user->name . "!");
        return $ctx;
    }
    elsif ($chat =~ /^(\S+)\-\-/) {
        my $target = $1;
        return if lc($target) eq lc($user->name);
        my $ctx = ODCHBot::Context->new(user => $user, bot => $self->bot);
        $ctx->reply_hub("$target has lost a karma point from " . $user->name . "!");
        return $ctx;
    }
}

1;
