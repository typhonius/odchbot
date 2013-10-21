ODCHBot [![Build Status](https://travis-ci.org/odchbot/odchbot.png?branch=v3)](https://travis-ci.org/odchbot/odchbot)
=======

ODCHBot is a bot written in Perl to provide additional features for [OpenDCHub](https://github.com/odchbot/opendchub).
The core bot provides an easily extensible framework for creating commands that range from simple text response to more complicated HTTP Requests, data storage and calculation.

Recommended version of OpenDCHub to use ODCHBot with is **0.7.16**

Prerequisites
=============

Core
----
The core code requires the following perl modules:

- DateTime
- DateTime::Duration
- DateTime::Format::Duration
- DBD::SQLite
- DBI
- Exporter
- FindBin
- Module::Load
- Number::Bytes::Human
- SQL::Abstract
- SQL::Abstract::Limit
- Storable
- Switch
- Text::Tabs
- Time::HiRes
- YAML
- YAML::AppConfig
- YAML::Syck

Commands
--------
The commands packaged with the bot require the following perl modules:

- Date::Parse
- Data::Dumper;
- HTTP::Request::Common
- HTML::Strip
- HTML::Parser
- HTML::Entities
- IPC::System::Simple
- JSON
- List::Util
- LWP::Simple
- Mail::Sendmail
- Math::Round;
- Number::Format
- POSIX
- Scalar::Util
- String::Random
- Sys::Hostname
- WWW::TheMovieDB
- XML::Simple

Installing Perl Modules
------------------
The simplest way to install all of these is to use cpanimus:

    curl -L http://cpanmin.us | perl - --sudo App::cpanminus
    sudo cpan App::cpanminus
    cpanm <modulename>

If any installs do not succeed, the following is recommended:

    cpan install <module> #to get the download URL
    wget <download URL>
    gzip -d <package>.tar.gz
    tar xvf <package>.tar
    cd <package>
    perl Makefile.pl
    make
    make install

* * *

Instructions
============
Installation
------------
Copy ```odchbot.yml.example``` to ```odchbot.yml``` and fill in settings in the db section depending on which db driver is being used. The bot is able to install itself into either a SQLite, MySQL, or PgSQL database although it is preconfigured for SQLite and no further changes are necessary if SQLite is to be used.

On first usage the bot will initialise a commands registry. Any commands stored in the commands directory will get loaded into the bot's memory whereupon they may be executed by users with adequate permissions.


Usage
-----

Permissions
-----------
There is a bitwise system with permissions whereby users are assigned a number when they first log in:
This number corresponds to the ```odch::type_get_types``` command that can be executed on a user. Further details may be found in DCBUser.pm with the important numbers being:

 - ANONYMOUS      = 4
 - AUTHENTICATED  = 8
 - OPERATOR       = 16
 - ADMINISTRATOR  = 32

These tie in exactly with permissions stated in the command YAML files meaning users of a permission not included in the YAML file will not be able to execute the command provided by the file.

Commands
--------
The commands system with odchbot allows a plugable and hookable framework where new commands may be added or removed in order to fulfil needs. All commands should be stored in the 'commands' directory and consist of a YAML file for configuration and a pm file containing the command code.

* * *

Configuration
-------------
The YAML file that holds all configuration for the command should be called [commandname].yml and be structured as follows (taken from tell.yml):

    name: tell
    description: Allows users to leave messages for other users. Usage: -tell <user> <message>
    required: 0
    system: 0
    permissions:
     - ANONYMOUS
     - AUTHENTICATED
     - OPERATOR
     - ADMINISTRATOR
    hooks:
     - postlogin
     - line

The name specified in the YAML file should match the filename of the command. This is what the user will type in to trigger the command. A description for the command should also be included and should describe functionality and usage of the command.
Due to storage specifications, the name of the command may be no longer than 30 characters and the description may be no longer than 255 characters.
Required commands are not allowed to be disabled by the bot and usually form some kind of key functionality.
System commands are those prepackaged with the bot.
Permssions follows the core permission system with only those users who have matching permissions being able to execute the command. 
NB the command will still run on hooks and affect users despite their permission level. It is only direct calling of the command in chat that is affected by the permission configuration.
hooks defines which hooks the commands are triggered on in conjunction with the main command call. hooks should be an array with a new hook on each line, in this case tell will be triggered by postlogin and line hooks.

Command file
------------
The file containing the command code should be named <commandname>.pm
The command file should, at the very least define a ```main{}``` subroutine. This is the subroutine that will fire when a user executes the command via chat. Any hooks that are defined will allow the subroutine named after the hook to be called. For example, in the tell command there are subroutines for main, postlogin and line.
main {} is executed when a user calls -tell from chat
postlogin {} is called after a user is successfully validated
line{} runs with every chatline.

Access is granted to the following globals when modules are loaded and these may be used within the commands:

 - ```DCBSettings::cwd``` - current working directory
 - ```DCBSettings::config``` - hub/bot config
 - ```DCBDatabase::dbh``` - db handle (likely unused)
 - ```DCBCommon::registry``` - commands registry
 - ```DCBUser::userlist``` - all users
 - ```DCBCommon::COMMON``` - Miscellaneous global for all modules to use
 
When processing all commands, there are three variables provided for use by the command.

    my $command = shift;
    my $user = shift;
    my $chat = shift;

<span style="color: red">The first is the name of the command</span>, passed through from `commands_run_commands{}`, the second is the `$user` object and <span style="color: blue">the third is any additional chatlines</span> that were sent as parameters to the command.

>\-<span style="color: red">coin</span> <span style="color: blue">Shall I go out today?</span>

The `$user` object of the user calling the command is provided to all commands as the 2nd parameter. This may be used in any way and provides all of the properties that a `user_load` or `user_load_by_name`.
    
    $user = {
      'uid' => 143,
      'name' => 'The_User_Name',
      'permission' => 16,
      'join_time' => 1370350185,
      'join_share' => 242142,
      'connect_time' => 1370540256,
      'connect_share' => 2499204,
      'disconnect_time' => 1370350265,
      'new' => 0,
      'ip' => '55.138.12.214',
      'client' => '<RAWRDC++ V:v3,M:P,H:1/3/3,S:7>',
    };

The properties provided may be accessed by `$user->{$property_name}`. If the name is required to report back to the user one may use `$user->{'name'}`. If a user is required to be looked up on the ```$userlist``` the user information may be located with ```DCBUser::userlist->{lc($name)}```. It's important to ensure the name is lowercased otherwise no information will be returned.


Returns from commands
---------------------
Commands wishing to return some kind of message or action to chat/the user should recreate the following structure at the end of their subroutines in order to pass meaningful information back to the main bot.
An array containing arrays of hashes is the structure and allows limitless responses and actions. Within each hash a number of specified elements must be returned.
param should be either message or action

Use either 'message' or 'action' for the data to be sent to either `odch_sendmessage` or `odch_action` respectively. 
  - message allows for a variety of message types to be used to communicate with users.
  - action allows bot level actions to run such as kicking users or banning nicknames.

The 'type' element is used to define what kind of message should be sent:

1. Message from the hub in main chat that everybody sees (Similar to the MOTD)
2. Message from the bot in main chat that only the recipient sees
3. PM from the bot to a user in a seperate PM window
4. Message from the bot in main chat that everybody sees (Most common)
5. PM from the bot to all users. (Mass message)
6. PM from 'fromuser' to 'user' (spoofed)
7. Message from the bot to all logged in Operators
8. PM from the hub to 'user' in a seperate PM window
9. PM from 'fromuser' to 'user' that will only show to 'user' (spoofed)
10. Message from 'user' to mainchat (spoofed)
11. Raw data to 'user'
12. Message from the bot to all logged in admins

user and fromuser are related to the message type and may sometimes be omitted (in the case of chat to all users etc).

    my @return = ();
      @return = (
        {
          param    => "message",
          message  => "Welcome for the first time: $user->{name}",
          type     => 4,
          user     => '',
          fromuser   => '',
        },
        {
          param    => "action",
          user     => $user->{name},
          action   => 'kick',
        },
      );
    }

* * *

Hooks
-----
There are a number of 'hooks' that can be taken advantage of when creating commands. These hooks are activated with certain hub events. The events are as follows:

 - init: Invoked when the hub starts up. Useful for instantiating globals/populating variables from db values.
 - prelogin: User is being validated
 - postlogin: Successful validation
 - line: A line of chat is spoken
 - pm: A private message is sent
 - timer: The timer has fired (usually every 15 minutes)
 - logout: The user has disconnected
 - alter: Allows a command to alter any other command when it is executed.

With most of the hooks, the data provided will be:

 - The name of the command
 - The user in focus (logging in, saying chat)
 - Additional parameters (if necessary)

Although sometimes (such is the case with the timer and init) there won't be a user parameter.

The purpose of hooks is to allow commands to have additional functionality at times where a user is not calling a command in the usual fashion. An example of this may be found within the 'tell' command. Although the main tell command creates a message for other users, the postlogin and line hooks are used to find when a user either speaks on logs in as an indicator to send the user the message.

The alter hook is special insofar as the return structure should match the variables provided to the functions.
Variables provided are the same as any standard hook or command:

 - command name
 - hook name (which will be alter)
 - user the hook relates to
 - a string consisting of the name of the hook to alter followed by any additional parameters

 A typical alter hook could be to disable any commands if they start with the letter 't':

 It is **imperative** that any subroutine in the \[command\].pm file returns _something_. Whether this is a structured ```@return``` array or just an empty Perl ```return;``` does not matter. However without returning there is the chance that it could prevent execution of subsequent functionality.


Database Table/Config Installation
---------------------------
Commands are also able to provide their own table structure to be created in the database on command install by invoking the `schema{}` subroutine. Additionally, the creation of configuration variables is possible within the same subroutine.
By creating, and returning, an associative array of 'schema' and/or 'config', the bot will create tables and variables that are ready for the command to use.
Any table declarations should exist in the schema array and should be keyed by table name. Within that key should be an array of fields with field descriptions keyed by the table column name.
There is no restriction on the number of tables/fields that can be created in this way.
Configuration may be created by entering in key/value elements underneath the config element. A standard that should ideally be kept is to prefix the key of any configuration


    sub schema {
      my %schema = (
        schema => ({
          favorite_colors => {
            id => {
              type          => "INTEGER",
              not_null      => 1,
              primary_key   => 1,
              autoincrement => 1,
            },
            color => { type => "VARCHAR(35)", },
            time  => { type => "INT", },
            username  => {
              type     => "INT",
              not_null => 1,
            },
          },
          color_index => {
            color => { type => "VARCHAR(35)", },
            color_file => { type => "BLOB", },
          },
        }),
        config => {
          number_votes => 1,
          last_year_favorite_color => "red",
          default_thanks => "Thank you for selecting your favorite color",
        },
      );
      return \%schema;
    }

If a command is uninstalled, the database table and any configuration specified in the `schema{}` subroutine will be removed and all data lost. This is the major difference between disabling a command and uninstalling.
Due to requirements of the bot, the `%schema` array must be returned by reference.

Debugging/Logging
-----------------

TODO: create a log file and write to that

Troubleshooting/Bugs
--------------------
Submit a bug report by using the -bug command or by contacting <odchbot@gmail.com>
