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
  my $message = '';
  my ($name, $title, $rtng, $desc, $year) = '';
  
  while(1) {
    my $random_number = int(rand(10000));
    my $info = $api->Movies::info({'movie_id' => $random_number});
    my $json = decode_json($info);
    if ($json->{'status_code'}) { next; }
		 
      my $adult = $json->{'adult'};
      if ($adult ne 'false')  { next;}
	  my $languages = $json->{'spoken_languages'};
      my $foreign = 1;
      foreach my $language (@$languages) {
      if ($language->{'iso_639_1'} eq 'en') { $foreign = 0;}}
	  unless ($foreign == 0) { next;}
	  my $status = $json->{'status'};
	  if (($status) eq 'In Production') { next; }
	  my $vote = $json->{'vote_count'};
	  if ($vote < 100) { next; }
	  my $rtng = $json->{'vote_average'};
      if ($rtng < 6.0) { next; };
	  my $name = $json->{'original_title'};
      my $desc = $json->{'overview'};
	  my $full_date = $json->{'release_date'};
      my ($year) = split( /\-/, $full_date );
	  if ($year < 1960) { next; } 
      return ($name,$rtng,$desc,$year);
	  }
      
    

 

    my @return = ();
	
	@return = (
	  
    {
      param => "message",
      message => sprintf("Title=> %s\nYear=> %s\nRating=> %s\nDescription=> %s\n",$name,$year,$rtng,$desc),
      user => $user->{name},
      touser => '',
      type => 2,
 
    },  
 );
 return @return;

 }

1;

