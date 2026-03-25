package ODCHBot::Context;
use Moo;
use Carp qw(croak);

# Message delivery types
use constant {
    HUB_PUBLIC       => 1,
    PUBLIC_SINGLE    => 2,
    BOT_PM           => 3,
    PUBLIC_ALL       => 4,
    MASS_MESSAGE     => 5,
    SPOOF_PM_BOTH    => 6,
    SEND_TO_OPS      => 7,
    HUB_PM           => 8,
    SPOOF_PM_SINGLE  => 9,
    SPOOF_PUBLIC     => 10,
    RAW              => 11,
    SEND_TO_ADMINS   => 12,
};

has user    => (is => 'ro');                      # ODCHBot::User who triggered this
has text    => (is => 'ro', default => '');        # Raw text / arguments
has bot     => (is => 'ro', required => 1);        # ODCHBot::Core instance
has event   => (is => 'ro', default => 'command'); # What triggered this context

# Accumulated responses
has _responses => (is => 'ro', default => sub { [] });

sub args { $_[0]->text }

sub config     { $_[0]->bot->config }
sub db         { $_[0]->bot->db }
sub users      { $_[0]->bot->users }
sub adapter    { $_[0]->bot->adapter }
sub bus        { $_[0]->bot->bus }

# --- Response Methods ---

sub reply {
    my ($self, $message) = @_;
    push @{ $self->_responses }, {
        type    => PUBLIC_SINGLE,
        message => $message,
        user    => $self->user ? $self->user->name : '',
        touser  => '',
    };
    return $self;
}

sub reply_public {
    my ($self, $message) = @_;
    push @{ $self->_responses }, {
        type    => PUBLIC_ALL,
        message => $message,
        user    => '',
        touser  => '',
    };
    return $self;
}

sub reply_hub {
    my ($self, $message) = @_;
    push @{ $self->_responses }, {
        type    => HUB_PUBLIC,
        message => $message,
        user    => '',
        touser  => '',
    };
    return $self;
}

sub reply_pm {
    my ($self, $message, %opts) = @_;
    push @{ $self->_responses }, {
        type    => BOT_PM,
        message => $message,
        user    => $opts{to} // ($self->user ? $self->user->name : ''),
        touser  => '',
    };
    return $self;
}

sub send_to_ops {
    my ($self, $message) = @_;
    push @{ $self->_responses }, {
        type    => SEND_TO_OPS,
        message => $message,
        user    => '',
        touser  => '',
    };
    return $self;
}

sub send_raw {
    my ($self, $raw, %opts) = @_;
    push @{ $self->_responses }, {
        type    => RAW,
        message => $raw,
        user    => $opts{to} // ($self->user ? $self->user->name : ''),
        touser  => '',
    };
    return $self;
}

sub mass_message {
    my ($self, $message) = @_;
    push @{ $self->_responses }, {
        type    => MASS_MESSAGE,
        message => $message,
        user    => $self->user ? $self->user->name : '',
        touser  => '',
    };
    return $self;
}

sub spoof_public {
    my ($self, $from, $message) = @_;
    push @{ $self->_responses }, {
        type    => SPOOF_PUBLIC,
        message => $message,
        user    => $from,
        touser  => '',
    };
    return $self;
}

sub kick {
    my ($self, $target, $reason) = @_;
    my $name = ref $target ? $target->name : $target;
    push @{ $self->_responses }, {
        action  => 'kick',
        target  => $name,
        message => $reason // '',
    };
    return $self;
}

sub ban {
    my ($self, $target, $reason) = @_;
    my $name = ref $target ? $target->name : $target;
    push @{ $self->_responses }, {
        action  => 'nickban',
        target  => $name,
        message => $reason // '',
    };
    return $self;
}

sub unban {
    my ($self, $target) = @_;
    my $name = ref $target ? $target->name : $target;
    push @{ $self->_responses }, {
        action  => 'unnickban',
        target  => $name,
    };
    return $self;
}

sub gag {
    my ($self, $target) = @_;
    my $name = ref $target ? $target->name : $target;
    push @{ $self->_responses }, {
        action => 'gag',
        target => $name,
    };
    return $self;
}

sub ungag {
    my ($self, $target) = @_;
    my $name = ref $target ? $target->name : $target;
    push @{ $self->_responses }, {
        action => 'ungag',
        target => $name,
    };
    return $self;
}

sub responses { @{ $_[0]->_responses } }

sub has_responses { scalar @{ $_[0]->_responses } > 0 }

1;
