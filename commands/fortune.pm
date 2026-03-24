package fortune;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use DCBCommon;

sub main {
  my $command = shift;
  my $user = shift;
  my @return = ();

  my @fortunes = fortune_list();
  my $fortune = $fortunes[int(rand(scalar @fortunes))];

  @return = ({
    param   => "message",
    message => "Fortune for $user->{name}:\n\"$fortune\"",
    user    => '',
    touser  => '',
    type    => MESSAGE->{'PUBLIC_ALL'},
  });
  return @return;
}

sub fortune_list {
  return (
    'The best time to plant a tree was 20 years ago. The second best time is now.',
    'In the middle of difficulty lies opportunity. - Albert Einstein',
    'The only way to do great work is to love what you do. - Steve Jobs',
    'It does not matter how slowly you go as long as you do not stop. - Confucius',
    'Stay hungry, stay foolish. - Steve Jobs',
    'The future belongs to those who believe in the beauty of their dreams. - Eleanor Roosevelt',
    'Not all those who wander are lost. - J.R.R. Tolkien',
    'Imagination is more important than knowledge. - Albert Einstein',
    'Talk is cheap. Show me the code. - Linus Torvalds',
    'First, solve the problem. Then, write the code. - John Johnson',
    'Any sufficiently advanced technology is indistinguishable from magic. - Arthur C. Clarke',
    'The universe is under no obligation to make sense to you. - Neil deGrasse Tyson',
    'There are only two hard things in Computer Science: cache invalidation and naming things. - Phil Karlton',
    'The best error message is the one that never shows up. - Thomas Fuchs',
    'Programs must be written for people to read, and only incidentally for machines to execute. - Harold Abelson',
    'Debugging is twice as hard as writing the code in the first place. - Brian Kernighan',
    'The most dangerous phrase in the language is "We have always done it this way." - Grace Hopper',
    'Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away. - Antoine de Saint-Exupery',
    'The secret of getting ahead is getting started. - Mark Twain',
    'Before software can be reusable it first has to be usable. - Ralph Johnson',
    'A ship in harbor is safe, but that is not what ships are built for. - John A. Shedd',
    'You miss 100% of the shots you don\'t take. - Wayne Gretzky',
    'The only true wisdom is in knowing you know nothing. - Socrates',
    'Life is what happens when you\'re busy making other plans. - John Lennon',
    'In theory, there is no difference between theory and practice. But in practice, there is. - Jan L. A. van de Snepscheut',
    'If it works, don\'t touch it.',
    'There are 10 types of people in the world: those who understand binary, and those who don\'t.',
    'A user interface is like a joke. If you have to explain it, it\'s not that good.',
    'To iterate is human, to recurse divine. - L. Peter Deutsch',
    'Yesterday is history, tomorrow is a mystery, today is a gift. That\'s why it\'s called the present.',
    'The definition of insanity is doing the same thing over and over and expecting different results.',
    'Fortune favors the bold. - Virgil',
    'The best revenge is massive success. - Frank Sinatra',
    'Always code as if the guy who ends up maintaining your code will be a violent psychopath who knows where you live. - John F. Woods',
    'Nine people can\'t make a baby in a month. - Fred Brooks',
    'Measuring programming progress by lines of code is like measuring aircraft building progress by weight. - Bill Gates',
    'Be yourself; everyone else is already taken. - Oscar Wilde',
    'Two things are infinite: the universe and human stupidity; and I\'m not sure about the universe. - Albert Einstein',
    'The early bird gets the worm, but the second mouse gets the cheese.',
    'I have not failed. I\'ve just found 10,000 ways that won\'t work. - Thomas Edison',
  );
}

1;
