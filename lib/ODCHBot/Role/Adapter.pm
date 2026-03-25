package ODCHBot::Role::Adapter;
use Moo::Role;

requires 'send_message';    # ($type, $message, $user, $touser)
requires 'send_action';     # ($action, $target, $message)

has bot => (is => 'rw', weak_ref => 1);

1;
