package ODCHBot::Role::Command;
use Moo::Role;
use Carp qw(croak);
use ODCHBot::User;

requires 'execute';
requires 'meta_info';

has bot => (is => 'ro', required => 1, weak_ref => 1);

sub name        { $_[0]->meta_info->{name} }
sub description { $_[0]->meta_info->{description} // '' }
sub usage       { $_[0]->meta_info->{usage}       // '' }
sub permission  { $_[0]->meta_info->{permission}  // ODCHBot::User::PERM_ANONYMOUS }
sub aliases     { @{ $_[0]->meta_info->{aliases}   // [] } }
sub hooks       { @{ $_[0]->meta_info->{hooks}     // [] } }
sub required    { $_[0]->meta_info->{required}     // 0 }

# Table definitions for auto-creation (override in command)
sub tables { {} }

# Config defaults for this command (override in command)
# Returns a hashref of { key => default_value }
# These are merged into config on registration if not already set.
sub config_defaults { {} }

# Called once during registration
sub on_register {
    my ($self) = @_;

    # Merge config defaults (don't overwrite existing values)
    my $defaults = $self->config_defaults;
    for my $key (keys %$defaults) {
        unless (defined $self->config->get($key)) {
            $self->config->set($key, $defaults->{$key});
        }
    }

    # Auto-create any tables this command needs
    my $tables = $self->tables;
    for my $table_name (keys %$tables) {
        $self->bot->db->ensure_table($table_name, $tables->{$table_name});
    }

    # Register event bus hooks
    for my $hook ($self->hooks) {
        my $method = "on_$hook";
        if ($self->can($method)) {
            $self->bot->bus->on("hook.$hook", sub {
                $self->$method(@_);
            }, label => $self->name . ".$hook");
        }
    }
}

# Convenience accessors
sub config { $_[0]->bot->config }
sub db     { $_[0]->bot->db }
sub users  { $_[0]->bot->users }

1;
