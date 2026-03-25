package ODCHBot::Command::Topic;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'topic',
    description => 'View or set the hub topic',
    usage       => 'topic [new topic]',
    hooks       => ['init', 'postlogin'],
}}

sub execute {
    my ($self, $ctx) = @_;
    my $new_topic = $ctx->args;

    if (length($new_topic // '')) {
        unless ($ctx->user->permission_at_least(ODCHBot::User::PERM_OPERATOR)) {
            $ctx->reply($self->config->get('no_perms') // 'Insufficient permissions.');
            return;
        }
        $self->config->set('topic', $new_topic);
        $ctx->reply_hub("Topic changed to: $new_topic");
    }
    else {
        my $topic = $self->config->get('topic') // 'No topic set';
        my $short = $self->config->get('hubname_short') // '';
        $ctx->reply("Topic: $topic" . ($short ? " [$short]" : ''));
    }
}

sub on_init {
    my ($self, $data) = @_;
    my $topic = $self->config->get('topic') // return;
    my $ctx = ODCHBot::Context->new(bot => $self->bot);
    $ctx->reply_hub("Topic: $topic");
    return $ctx;
}

sub on_postlogin {
    my ($self, $data) = @_;
    my $user = $data->{user} or return;
    my $hub_name = $self->config->get('hubname') // 'Hub';
    my $topic = $self->config->get('topic');

    my $ctx = ODCHBot::Context->new(user => $user, bot => $self->bot);
    if ($topic) {
        $ctx->send_raw("\$HubName $hub_name - $topic", to => $user->name);
    }
    return $ctx;
}

1;
