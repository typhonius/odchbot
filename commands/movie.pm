package movie;

use utf8;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBUser;
use JSON;
use WWW::TheMovieDB;
my $api = new WWW::TheMovieDB({
        'key' => 'c2c73ebd1e25cbc29cf61158c04ad78a',
        'language' => 'en',
        'version' => '3',
        'type' => 'json',
        'uri' => 'http://api.themoviedb.org'
});

sub main {
  my $command = shift;
  my $user = shift;
  my $message = 'No movie found try again though~ :3';
  my $i = 0;

  do {{
    my $random_number = int(rand(10000));
    my $info = $api->Movies::info({'movie_id' => $random_number});
    my $json = decode_json($info);
    next if ($json->{'status_code'}
      || $json->{'adult'} ne 'false'
      || $json->{'status'} eq 'In Production'
      || 1960 > substr($json->{'release_date'}, 0, 4)
    );
    my $languages = $json->{'spoken_languages'};
    my $foreign = 1;
    foreach my $language (@$languages) {
      if ($language->{'iso_639_1'} eq 'en') {
        $foreign = 0;
      }
    }
    next unless ($foreign == 0);

    $message = "I found you a movie!";
    $message .= "\nTitle => " . $json->{'original_title'};
    $message .= "\nYear => " . substr($json->{'release_date'}, 0, 4);
    $message .= "\nGenres => ";
    my $genres = $json->{'genres'};
    foreach my $genre (@$genres) {
      $message .= "$genre->{'name'}, ";
    }
    $message .= "\nRating => " . $json->{'vote_average'};
    $message .= "\nDescription => " . $json->{'overview'};
    last;
  }} while ($i++ < 5);

  my @return = (
    {
      param => "message",
      message => $message,
      user => $user->{name},
      touser => '',
      type => 2,
 
    },  
 );
 return @return;

 }

1;
