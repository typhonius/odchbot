package ODCHBot::Command::User;
use Moo;
use ODCHBot::User;
use ODCHBot::Formatter qw(format_duration format_size);
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'user',
    description => 'Welcome messages on user login',
    usage       => 'user',
    permission  => ODCHBot::User::PERM_ANONYMOUS,
    hooks       => ['postlogin', 'prelogin', 'logout'],
    required    => 1,
}}

sub config_defaults {{
    user_op_login_notify         => 1,
    user_op_login_notify_message => 'Welcome online',
}}

sub execute {
    my ($self, $ctx) = @_;
    $ctx->reply("User command handles login/logout events.");
}

sub on_postlogin {
    my ($self, $data) = @_;
    my $user   = $data->{user} // return;
    my $is_new = $data->{is_new};
    my $hubname = $self->config->get('hubname') // 'the hub';

    my $ctx = ODCHBot::Context->new(bot => $self->bot, user => $user);

    if ($is_new) {
        $ctx->reply_public("Welcome to $hubname for the first time: " . $user->name);
    }
    else {
        $ctx->reply("Welcome back to $hubname " . $user->name);
    }

    # Notify hub when ops/admins log in
    if ($user->permission_at_least(ODCHBot::User::PERM_OPERATOR)
        && $self->config->get('user_op_login_notify'))
    {
        my $msg = $self->config->get('user_op_login_notify_message') // 'Welcome online';
        $ctx->reply_public("$msg " . $user->name);
    }

    # Personal welcome banner
    my $perm_name = $user->permission_name;
    my $member_time = format_duration($user->join_time // time());
    my $share_delta = format_size(($user->connect_share // 0) - ($user->join_share // 0));
    my $client = $user->client // 'Unknown';

    my $banner = "\n" . ('-' x 70) . "\n";
    $banner .= "***===[ " . $user->name . " :: $perm_name :: $client ]===***\n";
    $banner .= "***===[ Member for: $member_time :: Share delta: $share_delta ]===***\n";
    $banner .= '-' x 70;

    $ctx->reply($banner);
    return $ctx;
}

sub on_prelogin {
    my ($self, $data) = @_;
    return;
}

sub on_logout {
    my ($self, $data) = @_;
    return;
}

1;
