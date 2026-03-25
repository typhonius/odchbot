package TestBot;

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use YAML::Syck ();

# Create a fully configured bot + test adapter for unit testing.
# Returns ($bot, $adapter, $tmpdir)

sub setup {
    my (%opts) = @_;

    my $tmpdir = tempdir(CLEANUP => 1);
    my $db_dir = File::Spec->catdir($tmpdir, 'logs');
    mkdir $db_dir;

    # Write config YAML
    my $config = {
        config => {
            botname             => $opts{botname} // 'TestBot',
            botdescription      => 'Test bot',
            botemail            => 'test@localhost',
            botshare            => 100000,
            botspeed            => 'LAN(T1)',
            bottag              => 'TEST',
            cp                  => $opts{cp} // '-',
            hubname             => 'Test Hub',
            hubname_short       => 'TEST',
            timezone            => 'UTC',
            min_username        => 3,
            username_max_length => 35,
            username_anonymous  => 'Anonymous',
            allow_anon          => 1,
            no_perms            => 'You do not have adequate permissions!',
            version             => 'v4',
            debug               => 0,
            web_karma           => '',
            web_rules           => 'https://example.com/rules',
            web_website         => 'https://example.com',
            topic               => 'Welcome to Test Hub',
            winning_default     => 10,
            winning_max         => 100,
            search_min_length   => 3,
            search_return_limit => 100,
            ban_default_ban_time    => 300,
            ban_default_ban_message => 'You are banned',
            ban_handler             => 'bot',
            user_op_login_notify => 0,
            user_op_login_notify_message => 'Welcome online',
            db => {
                database => 'test.db',
                driver   => 'SQLite',
                host     => '',
                password => '',
                path     => 'logs',
                port     => '',
                username => '',
            },
            %{ $opts{config} // {} },
        },
    };

    my $config_file = File::Spec->catfile($tmpdir, 'odchbot.yml');
    YAML::Syck::DumpFile($config_file, $config);
    chmod 0600, $config_file;

    require ODCHBot::Core;
    require ODCHBot::Adapter::Test;

    my $bot = ODCHBot::Core->new(config_file => $config_file);
    my $adapter = ODCHBot::Adapter::Test->new(bot => $bot);
    $bot->adapter($adapter);
    $bot->init;

    return ($bot, $adapter, $tmpdir);
}

# Create a connected user for testing
sub make_user {
    my ($bot, %opts) = @_;
    my $name = $opts{name} // 'TestUser';
    my $perm = $opts{permission} // ODCHBot::User::PERM_ANONYMOUS();
    my ($user, $is_new) = $bot->users->connect_user(
        name       => $name,
        ip         => $opts{ip} // '192.168.1.1',
        permission => $perm,
    );
    return $user;
}

1;
