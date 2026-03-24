package TestHelper;

use strict;
use warnings;
use File::Temp qw(tempdir);

sub setup {
    # Create temp directory for test
    my $tmpdir = tempdir( CLEANUP => 1 );

    # Set up minimal config hash directly (avoids config_load path issues)
    $DCBSettings::config = {
        allow_anon       => 1,
        allow_external   => 1,
        allow_passive    => 1,
        botdescription   => 'TestBot',
        botemail         => 'test@localhost',
        botname          => 'TestBot',
        botshare         => 100000,
        botspeed         => 'LAN(T1)',
        bottag           => 'TEST',
        commandPath      => 'commands',
        cp               => '-',
        db               => {
            database => 'test.db',
            driver   => 'SQLite',
            host     => '',
            password => '',
            path     => $tmpdir,
            port     => '',
            username => '',
        },
        debug                  => 0,
        hubname                => 'Test Hub',
        hubname_short          => 'TEST',
        maintainer_email       => 'test@test.com',
        min_username           => 3,
        minshare               => 0,
        no_perms               => 'You do not have adequate permissions!',
        timezone               => 'UTC',
        username_anonymous     => 'Anonymous',
        username_max_length    => 35,
        version                => 'v3',
        ban_default_ban_time   => 300,
        ban_default_ban_message => 'You are banned',
        ban_handler            => 'bot',
        search_min_length      => 5,
        search_return_limit    => 100,
        winning_default        => 10,
        winning_max            => 100,
    };

    $DCBSettings::cwd = "$tmpdir/";

    return ( $tmpdir, $DCBSettings::config );
}

1;
