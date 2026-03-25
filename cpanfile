# ODCHBot v4 Dependencies

# Core framework
requires 'Moo',                    '>= 2.003';
requires 'Log::Log4perl',          '>= 1.49';
requires 'DBI',                    '>= 1.636';
requires 'DBD::SQLite',            '>= 1.54';
requires 'SQL::Abstract',          '>= 1.86';
requires 'YAML::Syck',             '>= 1.31';
requires 'Module::Load',           '>= 0.32';
requires 'Time::HiRes',            '>= 1.9741';
requires 'Scalar::Util';
requires 'Carp';

# Formatter
requires 'DateTime',               '>= 1.42';
requires 'DateTime::Duration';
requires 'DateTime::Format::Duration';
requires 'Number::Bytes::Human',   '>= 0.11';
requires 'POSIX';

# Commands with external dependencies
requires 'URI::Escape';
requires 'JSON';
requires 'LWP::UserAgent';
requires 'LWP::Simple';
requires 'HTTP::Request';
requires 'XML::Simple';
requires 'IPC::System::Simple',    '>= 1.25';

# Optional (for bug command email)
recommends 'Mail::Sendmail';
recommends 'Sys::Hostname';

# Optional (for movie command)
recommends 'WWW::TheMovieDB';

# Testing
on 'test' => sub {
    requires 'Test::More',         '>= 1.302';
    requires 'Test::Exception',    '>= 0.43';
    requires 'File::Temp';
    requires 'File::Spec';
};
