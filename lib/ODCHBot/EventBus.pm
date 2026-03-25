package ODCHBot::EventBus;
use Moo;
use Carp qw(croak);
use Scalar::Util qw(weaken);

has _listeners => (is => 'ro', default => sub { {} });
has _log       => (is => 'ro', default => sub { sub {} });

sub BUILD {
    my ($self) = @_;
    if ($self->{logger}) {
        $self->{_log} = $self->{logger};
    }
}

sub on {
    my ($self, $event, $callback, %opts) = @_;
    croak "Event name required"    unless $event;
    croak "Callback required"      unless ref $callback eq 'CODE';

    push @{ $self->_listeners->{$event} }, {
        callback => $callback,
        priority => $opts{priority} // 50,
        label    => $opts{label}    // 'anonymous',
    };

    # Keep sorted by priority (lower = earlier)
    @{ $self->_listeners->{$event} } =
        sort { $a->{priority} <=> $b->{priority} }
        @{ $self->_listeners->{$event} };

    return $self;
}

sub off {
    my ($self, $event, $label) = @_;
    return unless $self->_listeners->{$event};

    @{ $self->_listeners->{$event} } =
        grep { $_->{label} ne $label }
        @{ $self->_listeners->{$event} };

    return $self;
}

sub emit {
    my ($self, $event, $data) = @_;
    $data //= {};

    my $listeners = $self->_listeners->{$event} // [];
    my @results;

    for my $listener (@$listeners) {
        my $result = eval { $listener->{callback}->($data) };
        if ($@) {
            $self->_log->("warn", "EventBus: listener '$listener->{label}' failed on '$event': $@");
            next;
        }
        push @results, $result if defined $result;

        # Allow listeners to halt propagation
        last if $data->{_stop_propagation};
    }

    return \@results;
}

sub listeners_for {
    my ($self, $event) = @_;
    return @{ $self->_listeners->{$event} // [] };
}

sub clear {
    my ($self) = @_;
    %{ $self->_listeners } = ();
    return $self;
}

1;
