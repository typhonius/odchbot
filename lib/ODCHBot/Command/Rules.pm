package ODCHBot::Command::Rules;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'rules',
    description => 'Link to the hub rules',
    usage       => 'rules',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $url  = $self->config->get('web_rules') // $self->config->get('website') // '';
    my $name = $self->config->get('hubname') // 'this hub';
    $ctx->reply("Rules for $name: $url");
}

1;
