# Core bot dependencies
requires 'DateTime';
requires 'DateTime::Duration';
requires 'DateTime::Format::Duration';
requires 'DBI';
requires 'DBD::SQLite';
requires 'JSON';
requires 'Log::Log4perl';
requires 'Log::Dispatch::File';
requires 'Module::Load';
requires 'Number::Bytes::Human';
requires 'SQL::Abstract';
requires 'YAML';
requires 'YAML::AppConfig';
requires 'YAML::Syck';

# Command-specific dependencies
feature 'commands', 'Optional modules used by individual commands' => sub {
    requires 'Clone';
    requires 'HTTP::Request';
    requires 'IPC::System::Simple';
    requires 'LWP::Simple';
    requires 'LWP::UserAgent';
    requires 'Mail::Sendmail';
    requires 'URI::Escape';
    requires 'WWW::TheMovieDB';
    requires 'XML::Simple';
};
