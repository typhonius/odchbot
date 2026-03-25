package ODCHBot::Command::Website;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'website',
    description => 'Link to the hub website',
    usage       => 'website',
}}

sub execute {
    my ($self, $ctx) = @_;
    my $url = $self->config->get('website') // '';
    $ctx->reply("Website: $url");
}

1;
