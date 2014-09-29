package DCBDatabase;

use strict;
use warnings;
use Switch;
use YAML::AppConfig;
use DBI;
use SQL::Abstract;
use SQL::Abstract::Limit;

use Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( db_insert db_select db_update db_delete db_do );

use Module::Load;
use FindBin;
use lib "$FindBin::Bin";
use DCBSettings;
use DCBUser;

sub new { return bless {}, shift }

sub db_init() {

  # Check to see if the database has been set up.
  db_connect();
  my @tables = $DCBDatabase::dbh->tables;

  unless ( grep $_ =~ 'users', @tables ) {
    db_install();
  }
}

# Provide wrapper functions so commands do not have
# to touch the database themselves.
sub db_connect {
  my $db  = $DCBSettings::config->{db};
  my $dsn = "dbi:$db->{driver}:";
  my $module = 'DBD::' . $db->{driver};

  # If the specific DB driver module is not installed we must error out as otherwise nothing will get installed.
  eval {
    load $module;
    $module->import();
  };
  if ($@) {
    print "Required module $module missing! Unable to connect to database.\n";
    die;
  }

  switch ( $db->{driver} ) {
    case /^SQLite/ {
      $dsn .= $DCBSettings::cwd . $db->{path} . '/' . $db->{database};
    }
    case /^[mysql|Pg]/ {
      $dsn .= "database=$db->{database};host=$db->{host};port=$db->{port}";
    }
    else {
      $dsn .= "$db->{database}:$db->{host}:$db->port";
    }
  }

# We could also move the initial db connection into here our $dbh = db_connect(); and then if that returns false we can attempt an install_db()
# That would probably be quicker than the dodgy grep @tables method. Although with sqlite if you try and connect it creates it for you...
# we can always put a try/catch in here for connecting to db and folder if we want fully configurable folders
# eval {
#return DBI->connect("dbi:$config{dbPlatform}:$config{dbPort}" . $cwd . $config{dbPath} . '/' . $config{dbName}, $config{dbUser}, $config{dbPassword}) or die "Unable to connect to database: $DBI::errstr";
# };
#if ($@) {
#unless (-d $cwd . $config{dbPath}) {
#  mkdir $cwd . $config{dbPath}, 0755 or die "Unable to mkdir: $!";
# return DBI->connect("dbi:$config{dbPlatform}:$config{dbPort}" . $cwd . $config{dbPath} . '/' . $config{dbName}, $config{dbUser}, $config{dbPassword}) or die "Unable to connect to database: $DBI::errstr";
#}
#}
  our $dbh = DBI->connect( $dsn, $db->{username}, $db->{password} )
    or die "Unable to connect to database: $DBI::errstr";
}

sub db_table_exists {
  my $table = shift;

  my $sth = $DCBDatabase::dbh->table_info('%', '%', $table, 'TABLE');
  if ($sth->fetch) {
    return 1;
  }
  return 0;
}

sub db_create_table {
  # TODO my $stmt_and_val = $sql->generate('create table', \$table, \@fields);
  my $schema = shift;
  my $install = '';
  foreach my $table (keys %{$schema->{schema}}) {
    if ($table && $schema->{schema}->{$table}) {
      my $fields = $schema->{schema}->{$table};
      if (!db_table_exists($table)) {
      $install = "CREATE TABLE $table (";
        foreach my $key (keys %{$fields}) {
          $install .= "$key $fields->{$key}->{type}";
          if ($fields->{$key}->{not_null}) {
            $install .= " NOT NULL";
          }
          if ($fields->{$key}->{primary_key}){
            $install .= " PRIMARY KEY";
          }
          if ($fields->{$key}->{autoincrement}) {
             switch ($DCBSettings::config->{db}->{driver}) {
               case /^SQLite/ {
                $install .= " AUTOINCREMENT";
               }
               case /^[mysql|Pg]/ {
                 $install .= " AUTO_INCREMENT";
               }
            }
          }
          $install .= ", "
        }
        substr($install, -2, 3) = ")";
        db_do($install);
      }
    }
  }
}

sub db_drop_table {
  my $schema = shift;
  foreach my $table (keys %{$schema->{schema}}) {
    if (db_table_exists($table)) {
      db_do("DROP TABLE $table");
    }
  }
}

# Things MUST be passed by reference (db_select('users', \@fields, \%where))
sub db_insert {
  my $table   = shift;
  my $inserts = shift;
  my $sql     = SQL::Abstract->new;
  my ( $stmt, @bind ) = $sql->insert( $table, $inserts );
  return db_execute( $stmt, @bind );
}

sub db_select {
  my $table  = shift;
  my $fields = shift;
  my $where  = shift;
  my $order  = shift;
  my $limit  = shift;
  my $offset = shift;
  my $sql = SQL::Abstract::Limit->new( limit_dialect => $DCBDatabase::dbh );
  my ( $stmt, @bind ) = $sql->select( $table, $fields, $where, $order, $limit, $offset );
  return db_execute( $stmt, @bind );
}

sub db_update {
  my $table   = shift;
  my $inserts = shift;
  my $where   = shift;
  my $sql     = SQL::Abstract->new;
  my ( $stmt, @bind ) = $sql->update( $table, $inserts, $where );
  return db_execute( $stmt, @bind );
}

sub db_delete( $ % ) {
  my $table = shift;
  my $where = shift;
  my $sql   = SQL::Abstract->new;
  my ( $stmt, @bind ) = $sql->delete( $table, $where );
  return db_execute( $stmt, @bind );
}

sub db_do( $ ) {
  my $query = shift;
  return $DCBDatabase::dbh->do($query)
    or die("Unable to complete query: $DBI::errstr");
}

sub db_execute {
  my ( $stmt, @bind ) = @_;
  my $sth = $DCBDatabase::dbh->prepare($stmt)
    or die "Couldn't prepare statement: " . $DCBDatabase::dbh->errstr;
  $sth->execute(@bind) or die "Couldn't execute statement: " . $sth->errstr;
  return $sth;
}

#--------------------------- Create the tables if they're not there
sub db_install {
  my %schema = (
    schema => ({
      users => {
        uid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        name => { type => "VARCHAR(35)", },
        join_time  => { type => "INT", },
        join_share  => { type => "INT", },
        connect_time => { type => "INT", },
        connect_share => { type => "INT", },
        permission => { type => "TINYINT" },
        ip => { type => "VARCHAR(18)", },
        client => { type => "VARCHAR(20)", },
        disconnect_time => { type => "INT", },
      },
      watchdog => {
        wid => {
          type          => "INTEGER",
          not_null      => 1,
          primary_key   => 1,
          autoincrement => 1,
        },
        time => { type => "INT", },
        users  => { type => "SMALLINT", },
        share => { type => "INT", },
        connections => { type => "INT", },
        disconnections => { type => "INT", },
        searches => { type => "INT", },
      },
      registry => {
        name => { type => "VARCHAR(30)", },
        description  => { type => "VARCHAR(255)", },
        path => { type => "VARCHAR(255)", },
        status => { type => "BOOL", },
        system => { type => "BOOL", },
        required => { type => "BOOL", },
        permissions => { type => "INT" },
        alias => { type => "BLOB" },
        hooks => { type => "BLOB" },
      },
    }),
  );
  db_create_table(\%schema);

  my %anonymous = ( 'name' => $DCBSettings::config->{username_anonymous}, 'uid' => 0 );
  db_insert( 'users', \%anonymous );

  my %bot = ( 'name' => $DCBSettings::config->{botname}, 'permission' => 64 );
  db_insert( 'users', \%bot );
}

1;
