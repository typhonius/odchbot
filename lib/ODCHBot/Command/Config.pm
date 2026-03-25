package ODCHBot::Command::Config;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'config',
    description => 'View or modify bot configuration',
    usage       => 'config get|set|delete|reload <key> [value]',
    permission  => ODCHBot::User::PERM_OPERATOR,
}}

sub execute {
    my ($self, $ctx) = @_;
    my ($action, $key, $value) = $ctx->args =~ /^(\S+)(?:\s+(\S+)(?:\s+(.+))?)?$/;

    unless ($action) {
        $ctx->reply("Usage: config get|set|delete|reload <key> [value]");
        return;
    }

    $action = lc $action;

    if ($action eq 'reload') {
        eval { $self->config->reload };
        if ($@) {
            $ctx->reply("Config reload failed: $@");
        }
        else {
            $ctx->reply("Configuration reloaded.");
        }
    }
    elsif ($action eq 'get') {
        unless ($key) {
            # List all keys
            my $data = $self->config->get;
            my $msg = "\nConfiguration:\n";
            for my $k (sort keys %$data) {
                next if ref $data->{$k};  # Skip nested
                $msg .= "  $k = $data->{$k}\n";
            }
            $ctx->reply($msg);
        }
        else {
            my $val = $self->config->get($key);
            if (defined $val && !ref $val) {
                $ctx->reply("$key = $val");
            }
            elsif (ref $val) {
                $ctx->reply("$key is a complex value (hash/array)");
            }
            else {
                $ctx->reply("$key is not set");
            }
        }
    }
    elsif ($action eq 'set') {
        unless ($key && defined $value) {
            $ctx->reply("Usage: config set <key> <value>");
            return;
        }
        eval { $self->config->set($key, $value) };
        if ($@) {
            $ctx->reply("Error: $@");
        }
        else {
            $ctx->reply("$key set to $value");
        }
    }
    elsif ($action eq 'delete') {
        unless ($key) {
            $ctx->reply("Usage: config delete <key>");
            return;
        }
        eval { $self->config->delete_key($key) };
        if ($@) {
            $ctx->reply("Error: $@");
        }
        else {
            $ctx->reply("$key deleted");
        }
    }
    else {
        $ctx->reply("Unknown action: $action (use get, set, delete, or reload)");
    }
}

1;
