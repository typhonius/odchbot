package ODCHBot::Command::Update;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'update',
    description => 'Pull latest bot code from git',
    usage       => 'update',
    permission  => ODCHBot::User::PERM_ADMINISTRATOR,
}}

sub execute {
    my ($self, $ctx) = @_;
    my $version = $self->config->get('version') // 'v3';
    my $base_dir = $self->config->base_dir;

    require IPC::System::Simple;
    require Cwd;

    my $old_dir = Cwd::getcwd();
    chdir($base_dir) or do {
        $ctx->reply("Cannot chdir to $base_dir: $!");
        return;
    };

    my $output = eval { IPC::System::Simple::capture("git", "pull", "origin", $version) };
    my $err = $@;

    chdir($old_dir) if $old_dir;

    if ($err) {
        $ctx->reply_public("Update failed: $err");
    }
    else {
        chomp($output);
        $ctx->reply_public($output);
    }
}

1;
