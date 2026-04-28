package NMDCClient;

# NMDC protocol client for connecting to a DC hub as a regular user.
# Handles $Lock/$Key handshake, login, chat send/receive.

use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use Log::Log4perl qw(:levels);

my $logger = Log::Log4perl->get_logger('NMDCClient');

sub new {
    my ($class, %opts) = @_;
    my $self = bless {
        host        => $opts{host}        || '127.0.0.1',
        port        => $opts{port}        || 4012,
        nick        => $opts{nick}        || 'Dragon',
        password    => $opts{password}    || '',
        description => $opts{description} || 'Hub Bot',
        email       => $opts{email}       || '',
        share       => $opts{share}       || 0,
        tag         => $opts{tag}         || '<odchbot V:4.0.0>',
        speed       => $opts{speed}       || 'LAN(T1)',
        socket      => undef,
        select      => undef,
        buffer      => '',
        connected   => 0,
        on_chat     => $opts{on_chat},     # callback: sub($nick, $message)
        on_pm       => $opts{on_pm},       # callback: sub($from, $message)
        on_join     => $opts{on_join},      # callback: sub($nick)
        on_quit     => $opts{on_quit},      # callback: sub($nick)
        on_myinfo   => $opts{on_myinfo},    # callback: sub($nick, $info)
    }, $class;
    return $self;
}

sub connect {
    my ($self) = @_;

    $logger->info("Connecting to $self->{host}:$self->{port}...");

    $self->{socket} = IO::Socket::INET->new(
        PeerAddr => $self->{host},
        PeerPort => $self->{port},
        Proto    => 'tcp',
        Timeout  => 10,
    ) or do {
        $logger->error("Connection failed: $!");
        return 0;
    };

    $self->{socket}->autoflush(1);
    $self->{select} = IO::Select->new($self->{socket});
    $self->{connected} = 1;

    $logger->info("Connected to hub");

    # Read the $Lock message
    my $lock_msg = $self->_read_message(5);
    unless ($lock_msg && $lock_msg =~ /^\$Lock\s+(\S+)/) {
        $logger->error("Expected \$Lock, got: " . ($lock_msg // 'nothing'));
        $self->disconnect();
        return 0;
    }

    my $lock = $1;
    my $key = lock_to_key($lock);

    # Send key + nick
    $self->_send("\$Supports|");
    $self->_send("\$Key $key|");
    $self->_send("\$ValidateNick $self->{nick}|");

    # Read messages until we get $Hello, $GetPass, or $ValidateDenide.
    # The hub may send $HubName, <Hub-Security> welcome, etc. first.
    my $logged_in = 0;
    my $attempts = 0;
    while ($attempts < 20) {
        my $response = $self->_read_message(5);
        last unless defined $response;
        $attempts++;

        if ($response =~ /\$GetPass/) {
            if ($self->{password}) {
                $self->_send("\$MyPass $self->{password}|");
                # Continue reading for $Hello or $BadPass
                next;
            } else {
                $logger->error("Hub requires password but none configured");
                $self->disconnect();
                return 0;
            }
        }
        elsif ($response =~ /\$ValidateDenide/) {
            $logger->error("Nick validation denied by hub");
            $self->disconnect();
            return 0;
        }
        elsif ($response =~ /\$BadPass/) {
            $logger->error("Bad password for $self->{nick}");
            $self->disconnect();
            return 0;
        }
        elsif ($response =~ /\$Hello\s+\Q$self->{nick}\E/) {
            $logged_in = 1;
            last;
        }
        # Ignore $HubName, <Hub-Security>, $Supports, $NickList, etc.
    }

    unless ($logged_in) {
        $logger->error("Login failed after $attempts messages");
        $self->disconnect();
        return 0;
    }

    # Send our info
    $self->_send("\$Version 1,0091|");
    $self->_send("\$GetNickList|");
    $self->_send_myinfo();

    $logger->info("Logged in as $self->{nick}");
    return 1;
}

sub disconnect {
    my ($self) = @_;
    if ($self->{socket}) {
        eval { $self->{socket}->close(); };
        $self->{socket} = undef;
    }
    $self->{connected} = 0;
    $self->{select} = undef;
    $self->{buffer} = '';
    $logger->info("Disconnected from hub");
}

sub is_connected {
    my ($self) = @_;
    return $self->{connected} && defined $self->{socket};
}

# Send a public chat message
sub send_chat {
    my ($self, $message) = @_;
    $self->_send("<$self->{nick}> $message|");
}

# Send a private message
sub send_pm {
    my ($self, $to_nick, $message) = @_;
    $self->_send("\$To: $to_nick From: $self->{nick} \$<$self->{nick}> $message|");
}

# Poll for incoming messages. Returns after timeout_ms or when a message is processed.
# Call this in a loop.
sub poll {
    my ($self, $timeout_ms) = @_;
    $timeout_ms //= 100;

    return unless $self->{select};

    my @ready = $self->{select}->can_read($timeout_ms / 1000.0);
    return unless @ready;

    my $buf;
    my $bytes = $self->{socket}->sysread($buf, 65536);

    if (!defined $bytes || $bytes == 0) {
        $logger->warn("Hub disconnected");
        $self->{connected} = 0;
        return;
    }

    $self->{buffer} .= $buf;

    # Process complete messages (pipe-delimited)
    while ($self->{buffer} =~ s/^([^|]*)\|//) {
        my $msg = $1;
        $self->_handle_message($msg);
    }
}

# -----------------------------------------------------------------------
# Internal methods
# -----------------------------------------------------------------------

sub _send {
    my ($self, $data) = @_;
    return unless $self->{socket};
    eval {
        $self->{socket}->syswrite($data);
    };
    if ($@) {
        $logger->error("Send failed: $@");
        $self->{connected} = 0;
    }
}

sub _send_myinfo {
    my ($self) = @_;
    # $MyINFO $ALL nick description<tag>$ $speed\x01$email$share$|
    my $info = sprintf(
        "\$MyINFO \$ALL %s %s%s\$ \$%s\x01\$%s\$%d\$|",
        $self->{nick},
        $self->{description},
        $self->{tag},
        $self->{speed},
        $self->{email},
        $self->{share},
    );
    $self->_send($info);
}

sub _read_message {
    my ($self, $timeout) = @_;
    $timeout //= 5;

    my $end = time() + $timeout;
    while (time() < $end) {
        # Check if we already have a complete message in buffer
        if ($self->{buffer} =~ s/^([^|]*)\|//) {
            return $1;
        }

        my @ready = $self->{select}->can_read(0.5);
        next unless @ready;

        my $buf;
        my $bytes = $self->{socket}->sysread($buf, 65536);
        return undef unless defined $bytes && $bytes > 0;

        $self->{buffer} .= $buf;
    }

    # Try one more time
    if ($self->{buffer} =~ s/^([^|]*)\|//) {
        return $1;
    }
    return undef;
}

sub _handle_message {
    my ($self, $msg) = @_;

    # Public chat: <nick> message
    if ($msg =~ /^<([^>]+)>\s*(.*)$/) {
        my ($nick, $text) = ($1, $2);
        if ($self->{on_chat} && $nick ne $self->{nick}) {
            $self->{on_chat}->($nick, $text);
        }
    }
    # Private message: $To: me From: nick $<nick> message
    elsif ($msg =~ /^\$To:\s+\Q$self->{nick}\E\s+From:\s+(\S+)\s+\$<[^>]+>\s*(.*)$/) {
        my ($from, $text) = ($1, $2);
        if ($self->{on_pm}) {
            $self->{on_pm}->($from, $text);
        }
    }
    # User join: $Hello nick
    elsif ($msg =~ /^\$Hello\s+(.+)$/) {
        my $nick = $1;
        if ($self->{on_join} && $nick ne $self->{nick}) {
            $self->{on_join}->($nick);
        }
    }
    # User quit: $Quit nick
    elsif ($msg =~ /^\$Quit\s+(.+)$/) {
        my $nick = $1;
        if ($self->{on_quit}) {
            $self->{on_quit}->($nick);
        }
    }
    # MyINFO: $MyINFO $ALL nick ...
    elsif ($msg =~ /^\$MyINFO\s+\$ALL\s+(\S+)\s+(.*)$/) {
        my ($nick, $info) = ($1, $2);
        if ($self->{on_myinfo}) {
            $self->{on_myinfo}->($nick, $info);
        }
    }
    # Hub name
    elsif ($msg =~ /^\$HubName\s+(.+)$/) {
        $logger->debug("Hub name: $1");
    }
    # Ignore other protocol messages silently
}

# -----------------------------------------------------------------------
# Lock-to-Key algorithm (ported from Rust odch-gateway/src/nmdc/lock_to_key.rs)
# -----------------------------------------------------------------------

sub lock_to_key {
    my ($lock_str) = @_;

    my @lock = map { ord($_) } split //, $lock_str;
    my $len = scalar @lock;
    return '' if $len < 3;

    my @key;

    # Step 1-2: XOR
    $key[0] = $lock[0] ^ $lock[$len - 1] ^ $lock[$len - 2] ^ 5;
    for my $i (1 .. $len - 1) {
        $key[$i] = $lock[$i] ^ $lock[$i - 1];
    }

    # Step 3: Nibble swap
    for my $i (0 .. $len - 1) {
        $key[$i] = (($key[$i] << 4) | ($key[$i] >> 4)) & 0xFF;
    }

    # Step 4: Encode special characters
    my $result = '';
    for my $b (@key) {
        if    ($b == 0)   { $result .= '/%DCN000%/'; }
        elsif ($b == 5)   { $result .= '/%DCN005%/'; }
        elsif ($b == 36)  { $result .= '/%DCN036%/'; }
        elsif ($b == 96)  { $result .= '/%DCN096%/'; }
        elsif ($b == 124) { $result .= '/%DCN124%/'; }
        elsif ($b == 126) { $result .= '/%DCN126%/'; }
        else              { $result .= chr($b); }
    }

    return $result;
}

1;
