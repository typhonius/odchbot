package ODCHBot::Command::Movie;
use Moo;
use ODCHBot::User;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'movie',
    description => 'Get a random movie recommendation',
    usage       => 'movie',
    permission  => ODCHBot::User::PERM_ANONYMOUS,
}}

sub execute {
    my ($self, $ctx) = @_;

    my $api_key = $self->config->get('movie_api_key');
    unless ($api_key) {
        $ctx->reply("Movie API key not configured. Set movie_api_key in config.");
        return;
    }

    require WWW::TheMovieDB;
    require JSON;

    my $api = WWW::TheMovieDB->new({
        key      => $api_key,
        language => 'en',
        version  => '3',
        type     => 'json',
        uri      => 'http://api.themoviedb.org',
    });

    my ($detail, $public) = ('', 'No movie found try again though~ :3');

    for my $attempt (0 .. 4) {
        my $random_id = int(rand(10000));
        my $info = eval { $api->Movies::info({ movie_id => $random_id }) };
        next unless $info;

        my $json = eval { JSON::decode_json($info) };
        next unless $json;
        next if $json->{status_code};
        next if ($json->{adult} // '') ne 'false';
        next if ($json->{status} // '') eq 'In Production';
        next if !$json->{release_date} || 1960 > substr($json->{release_date}, 0, 4);

        # English language check
        my $langs = $json->{spoken_languages} // [];
        next unless grep { ($_->{iso_639_1} // '') eq 'en' } @$langs;

        my $title = $json->{original_title} // 'Unknown';
        $public = $ctx->user->name . " you should watch $title!";
        $detail  = "\nTitle => $title";
        $detail .= "\nYear => " . substr($json->{release_date}, 0, 4);
        $detail .= "\nGenres => " . join(', ', map { $_->{name} } @{ $json->{genres} // [] });
        $detail .= "\nRating => " . ($json->{vote_average} // 'N/A');
        $detail .= "\nDescription => " . ($json->{overview} // 'No description');
        last;
    }

    $ctx->reply_public($public);
    $ctx->reply($detail) if $detail;
}

1;
