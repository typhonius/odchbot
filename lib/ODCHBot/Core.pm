package ODCHBot::Core;
use Moo;
use Carp qw(croak);
use Time::HiRes qw(gettimeofday tv_interval);
use Log::Log4perl qw(:easy);

use ODCHBot::Config;
use ODCHBot::Database;
use ODCHBot::EventBus;
use ODCHBot::UserStore;
use ODCHBot::CommandRegistry;
use ODCHBot::Context;
use ODCHBot::Formatter qw(escape_string);

our $VERSION = '4.0.0';

has config_file => (is => 'ro', required => 1);
has config      => (is => 'lazy');
has db          => (is => 'lazy');
has bus         => (is => 'lazy');
has users       => (is => 'lazy');
has commands    => (is => 'lazy');
has adapter     => (is => 'rw');
has boot_time   => (is => 'rw');

sub _build_config {
    my ($self) = @_;
    return ODCHBot::Config->new(file => $self->config_file);
}

sub _build_db {
    my ($self) = @_;
    my ($user, $pass) = $self->config->db_credentials;
    return ODCHBot::Database->new(
        dsn      => $self->config->db_dsn,
        username => $user,
        password => $pass,
    );
}

sub _build_bus {
    ODCHBot::EventBus->new(logger => sub {
        my ($level, $msg) = @_;
        if    ($level eq 'warn')  { WARN $msg }
        elsif ($level eq 'error') { ERROR $msg }
        else                      { DEBUG $msg }
    });
}

sub _build_users {
    my ($self) = @_;
    return ODCHBot::UserStore->new(db => $self->db);
}

sub _build_commands {
    my ($self) = @_;
    return ODCHBot::CommandRegistry->new(bot => $self);
}

sub init {
    my ($self) = @_;
    my $t0 = [gettimeofday];

    $self->boot_time(time());

    # Initialize logging
    my $log_conf = $self->config->base_dir . '/odchbot.log4perl.conf';
    if (-f $log_conf) {
        Log::Log4perl->init($log_conf);
    } else {
        Log::Log4perl->easy_init($DEBUG);
    }

    # Touch lazy builders in order
    $self->db;
    $self->users;
    $self->bus;
    $self->commands->discover_and_load;

    my $elapsed = tv_interval($t0);
    my $name = $self->config->get('botname') // 'ODCHBot';
    DEBUG sprintf("%s v%s loaded in %.3f seconds", $name, $VERSION, $elapsed);

    # Fire init event
    $self->bus->emit('hook.init', { bot => $self });

    return $self;
}

# --- Command Dispatch ---

sub dispatch_command {
    my ($self, $user, $text) = @_;

    my $cp = escape_string($self->config->get('cp') // '-');
    return unless $text =~ /^\Q$cp\E(\S+)(?:\s+(.*))?$/;

    my ($cmd_name, $args) = ($1, $2 // '');

    my $cmd = $self->commands->find($cmd_name);
    return unless $cmd;

    # Check disabled
    if ($self->commands->is_disabled($cmd->name)) {
        return $self->_simple_reply($user, "Command '$cmd_name' is currently disabled.");
    }

    # Check permission
    unless ($user->permission_at_least($cmd->permission)) {
        return $self->_simple_reply($user, $self->config->get('no_perms')
            // 'You do not have adequate permissions to use this function!');
    }

    my $ctx = ODCHBot::Context->new(
        user  => $user,
        text  => $args,
        bot   => $self,
        event => 'command',
    );

    eval { $cmd->execute($ctx) };
    if ($@) {
        ERROR "Command '$cmd_name' failed: $@";
        $ctx->reply("An error occurred while running '$cmd_name'.");
    }

    return $ctx;
}

sub _simple_reply {
    my ($self, $user, $message) = @_;
    my $ctx = ODCHBot::Context->new(user => $user, bot => $self);
    $ctx->reply($message);
    return $ctx;
}

# --- Hook Dispatch ---

sub emit_hook {
    my ($self, $hook, %data) = @_;
    $data{bot} = $self;
    return $self->bus->emit("hook.$hook", \%data);
}

# --- Bot Identity ---

sub bot_name  { $_[0]->config->get('botname')  // 'Dragon' }
sub bot_email { $_[0]->config->get('botemail')  // '' }
sub bot_share { $_[0]->config->get('botshare')  // 0 }
sub bot_speed { $_[0]->config->get('botspeed')  // '' }
sub bot_tag   { $_[0]->config->get('bottag')    // '' }
sub bot_desc  { $_[0]->config->get('botdescription') // '' }

1;
