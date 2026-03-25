package ODCHBot::CommandRegistry;
use Moo;
use Carp qw(croak);
use Module::Load qw(load);
use File::Glob qw(bsd_glob);
use Log::Log4perl qw(:easy);

has bot       => (is => 'ro', required => 1, weak_ref => 1);
has _commands => (is => 'ro', default => sub { {} });
has _aliases  => (is => 'ro', default => sub { {} });
has _disabled => (is => 'ro', default => sub { {} });

sub discover_and_load {
    my ($self) = @_;
    my $ns = 'ODCHBot::Command';

    # Find all command modules
    my @modules;
    for my $inc (@INC) {
        my $dir = "$inc/ODCHBot/Command";
        next unless -d $dir;
        for my $file (bsd_glob("$dir/*.pm")) {
            my ($name) = $file =~ m{/(\w+)\.pm$};
            next unless $name;
            push @modules, "${ns}::${name}" unless grep { $_ eq "${ns}::${name}" } @modules;
        }
    }

    my $loaded = 0;
    for my $module (sort @modules) {
        eval {
            load $module;
            my $cmd = $module->new(bot => $self->bot);
            $self->register($cmd);
            $loaded++;
        };
        if ($@) {
            my ($short) = $module =~ /::(\w+)$/;
            WARN "Failed to load command '$short': $@";
        }
    }

    INFO "Loaded $loaded commands";
    return $loaded;
}

sub register {
    my ($self, $cmd) = @_;
    croak "Command must consume ODCHBot::Role::Command"
        unless $cmd->does('ODCHBot::Role::Command');

    my $name = lc $cmd->name;
    $self->_commands->{$name} = $cmd;

    for my $alias ($cmd->aliases) {
        $self->_aliases->{lc $alias} = $name;
    }

    # Let the command set up its tables and hooks
    eval { $cmd->on_register };
    if ($@) {
        WARN "Command '$name' registration failed: $@";
    }

    return $self;
}

sub find {
    my ($self, $name) = @_;
    $name = lc($name // '');

    # Direct match
    return $self->_commands->{$name} if $self->_commands->{$name};

    # Alias match
    if (my $real = $self->_aliases->{$name}) {
        return $self->_commands->{$real};
    }

    return undef;
}

sub is_disabled {
    my ($self, $name) = @_;
    return $self->_disabled->{lc $name} // 0;
}

sub disable {
    my ($self, $name) = @_;
    $self->_disabled->{lc $name} = 1;
    return $self;
}

sub enable {
    my ($self, $name) = @_;
    delete $self->_disabled->{lc $name};
    return $self;
}

sub all {
    my ($self) = @_;
    return values %{ $self->_commands };
}

sub accessible_for {
    my ($self, $user) = @_;
    return grep {
        !$self->is_disabled($_->name)
        && $user->permission_at_least($_->permission)
    } $self->all;
}

sub unregister {
    my ($self, $name) = @_;
    $name = lc($name // '');
    my $cmd = delete $self->_commands->{$name} or return;

    # Remove aliases pointing to this command
    for my $alias (keys %{ $self->_aliases }) {
        delete $self->_aliases->{$alias} if $self->_aliases->{$alias} eq $name;
    }

    # Remove event bus listeners for this command's hooks
    for my $hook ($cmd->hooks) {
        $self->bot->bus->off("hook.$hook", $cmd->name . ".$hook");
    }

    delete $self->_disabled->{$name};
    return $cmd;
}

sub names {
    my ($self) = @_;
    return sort keys %{ $self->_commands };
}

1;
