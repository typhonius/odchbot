#!/usr/bin/perl -w

## Put extra dependencies here.
use DBI;
use Number::Format qw(format_bytes);
use DateTime;
use Math::Round;

## Do not alter after this point until stated ##
use strict;
use warnings;
use Config::IniFiles;

my $ConfigFile = "/home/vps/.opendchub/scripts/chaosbot.conf";
tie my %ini, 'Config::IniFiles', (-file => $ConfigFile);
my %Config = %{$ini{"config"}};

my $x = '';
my @array = ();
my $user = $ARGV[0];
my $user_perm = $ARGV[1];
my $arg_first = $ARGV[2];
my $arg_second = $ARGV[3];
my $userip = $ARGV[4];
my ($hubshare, $hubuptime) = split(':', $ARGV[5]);
my $fire = $Config{fire};

if ($fire == 0 && $user_perm < 2) {
die;
}

sub output( @ ) {
  my @array = @_;
  for($x=0;$x<@array;$x++) {
    $array[$x] = $array[$x] . "Þ";
  }

  print @array;
}
## Do not alter before this point ##

## Info Block ##

#1# Command Name: status
#2# Description: Shows a whole range of information about the hub, the bots and the users.
#3# Command used by: Users
#4# Author: KY
#5# Date Created: 23/10/2011
#6# Date added to Bot: 23/10/2011

## Variables available to the script:

# User initiating the script :: $user
# Permission level of the User :: $user_perm
#	0 = Non registered
#	1 = Registered
#	2 = Op
#	3 = Admin
# args1 (The first word after the command) :: $arg_first
# args2 (The second word after the command) :: $arg_second
# eg -testcommand args1 args2

## Output values

# Fill in the required return values here and leave output(@array); as is.
# @array[0] Is the user initiating the script
# @array[1] Is the user the script acts upon
# @array[2] Is the type of message to be sent using the sendmessage function
# @array[3] Is the message to be sent back
# @array[4] If there is an odch function to be used name it here. If not leave blank or null
# @array[5] $fire determines whether or not the script actually fires.

## Message Types (for @array[2])

# The most oft used 'types' when sending to sendmessage are as follows:
# 2 Displays in main chat ONLY to the user
# 3 Sends a PM to the user
# 4 Sends to main chat for everyone

## End Info Block ##


## Place your module specific code here

#my %Status = %{$ini{"status"}};
sub format ( @ ) {
  my($unf) = @_;
  my $days = int($unf/(24*60*60));
  my $hours = int($unf/(60*60))%24;
  my $mins = int($unf/60)%60;
  my $secs = int($unf%60);
  $days = $days <= 1 ? '' : ' ' . $days . ' day';
  $hours = $hours <= 1 ? '' : ' ' . $hours . ' hour'; 
  $mins = $mins <= 1 ? '' : ' ' . $mins . ' minute'; 
  $days = $days ? $days . 's' : $days;
  $hours = $hours ? $hours . 's' : $hours;
  $mins = $mins ? $mins . 's ' : $mins . ' ';
  my $formatted = $days . $hours . $mins . $secs . ' seconds';
  return $formatted;
}

sub daydbparse ( @ ) {
  my $dbh = DBI->connect("dbi:SQLite:" . $Config{dbloc} . $Config{db},"","");
  my($dow, $id, $lognumber) = @_;
  my $daynum = ($dow + $id);
  my $dayname = '';
  if ($daynum == 0 || $daynum == 7) {
    $dayname = 'Sunday';
  }
  elsif($daynum == 1 || $daynum == 8) {
    $dayname = 'Monday';
  }
  elsif($daynum == 2 || $daynum == 9) {
    $dayname = 'Tuesday';
  }
  elsif($daynum == 3 || $daynum == 10) {
    $dayname = 'Wednesday';
  }
  elsif($daynum == 4 || $daynum == 11) {
    $dayname = 'Thursday';
  }
  elsif($daynum == 5 || $daynum == 12) {
    $dayname = 'Friday';
  }
  elsif($daynum == 6 || $daynum == 13) {
    $dayname = 'Saturday';
  }

  my $userlist = '';
  my ($maxusers, $minusers) = ('1', '100000000000000000');
  my $sharelist = '';
  my ($maxshare, $minshare) = ('1', '100000000000000000');
  my $userquery = "SELECT users, share FROM (SELECT * FROM statusd ORDER BY id DESC limit ?,?) ORDER BY users DESC";
  my $userhandle = $dbh->prepare($userquery);
  $userhandle->execute((($id * 96) + 1), ($lognumber + ($id * 96)));
  $userhandle->bind_columns(\$userlist, \$sharelist);
  while ($userhandle->fetch()) {
    if ($userlist > $maxusers) {
      $maxusers = $userlist;
    }
    if ($userlist < $minusers) {
      $minusers = $userlist;
    }
    if ($sharelist > $maxshare) {
      $maxshare = $sharelist;
    }
    if ($sharelist < $minshare) {
      $minshare = $sharelist;
    }
  }
  # feed sub with $i where i is the day form today backwards.
  # in the sub it can be 96 * $i + 1 and then 96 * $i + 97
  # those are the limits and then the results can be spat back
  # to give daily users and shares for however long

  my $herp = $dayname . ': ' . $maxusers . '/' . $minusers . ' - ' . format_bytes($maxshare) . '/' . format_bytes(abs($minshare));
  return $herp;
}

my ($scriptstart, $totalmaxs, $totalmaxu, $totalminu, $totalmins) = ('', '', '', '', '');
my ($squery, $shandle, $lquery, $lhandle) = ('', '', '', '');
my $message = '';
my $dbh = DBI->connect("dbi:SQLite:" . $Config{dbloc} . $Config{db},"","");

$lquery = "SELECT scriptstart, totalmaxs, totalmaxu FROM $Config{statuslong} WHERE id = 1 ORDER BY id DESC LIMIT 1";
$lhandle = $dbh->prepare($lquery);
$lhandle->execute();
$lhandle->bind_columns(\$scriptstart, \$totalmaxs, \$totalmaxu);
  while ($lhandle->fetch()) {

    $message = 'Chaotic Neutral Status:

Record User Numbers:
Maximum Users Online: ' . $totalmaxu . '
Minimum Users Online: ' . $totalmaxu . '

Share Numbers:
Hub Max Share: ' . format_bytes($totalmaxs) . '
Hub Current Share: ' . format_bytes($hubshare) . '
Hub Min Share: ' . format_bytes($totalmins) . '

Server Status:
Server Uptime: ' . &format(`cat /proc/uptime | awk {'print \$1'}`) . '
Hub Uptime: ' . &format($hubuptime) . '
Bot Uptime: ' . &format((time() - $scriptstart));

  }
my ($id, $time, $users, $share, $connections, $disconnections, $searches) = ('', '', '', '', '', '', '');
$squery = "SELECT id, time, users, share, connections, disconnections, searches from statusd ORDER BY id desc limit 1";
$shandle = $dbh->prepare($squery);
$shandle->execute();
$shandle->bind_columns(\$id, \$time, \$users, \$share, \$connections, \$disconnections, \$searches);

while ($shandle->fetch()) {
  $message .= '

Misc Stats:
Connections: ' . $connections . '
Disconnections: ' . $disconnections . '
Searches ' . $searches;
}

my $now = DateTime->now();
$now->set_time_zone('Australia/Canberra');
my $today = DateTime->new(
  year => $now->year,
  month => $now->month,
  day => $now->day,
  hour => 0,
  minute => 0,
  second => 0,
  time_zone => 'Australia/Canberra',
);
my $daydiff = $now->subtract_datetime($today);
my $mindiff = $daydiff->minutes() + ($daydiff->hours() * 60);
my $lognum = round($mindiff / 15);

$message .= '

Recent User & Share details:
Users Max:Min - Share Max:Min
';

my $daystoshow = 7;
my $i = '';
for ($i=0; $i<$daystoshow; $i++) {
  $message .= &daydbparse($now->day_of_week, $i, $lognum) . "\n";
  # feed sub with $i where i is the day form today backwards. 
  # in the sub it can be 96 * $i + 1 and then 96 * $i + 97
  # those are the limits and then the results can be spat back
  # to give daily users and shares for however long
}

$array[0] = $user;
$array[1] = "";
$array[2] = "2";
$array[3] = $message;
$array[4] = "null";
$array[5] = $fire;

## Do not alter following line
output(@array);
