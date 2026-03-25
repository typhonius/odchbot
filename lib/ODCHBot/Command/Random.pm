package ODCHBot::Command::Random;
use Moo;
with 'ODCHBot::Role::Command';

sub meta_info {{
    name        => 'random',
    description => 'Generate a random sentence',
    usage       => 'random',
}}

my @NOUNS = qw(
    account action activity actor addition adjustment advertisement advice afternoon
    agreement air airplane airport alarm amount amusement anger angle animal answer
    apparatus apple appliance approval arch argument arithmetic arm army art attack
    attempt attention attraction authority baby back badge bag balance ball balloon
    banana band base baseball basin basket bat bath battle bead beam bean bear beast
    bed bedroom bee beef beetle beginner behavior belief bell berry bike bird birth
    birthday bit bite blade blood blow board boat body bomb bone book boot border
    bottle box boy brain brake branch bread breakfast breath brick bridge brother
    brush bubble bucket building bulb burn burst bushes business butter button
    cabbage cable cactus cake calculator calendar camera camp cannon canvas cap car
    card care carpenter carriage cart cast cat cattle cause cave cellar cemetery cent
    chain chair chalk chance change channel cheese cherry chess chicken children chin
    church circle clam class clock cloth cloud clover club coach coal coast coat
    cobweb coil collar color comb comfort committee company comparison competition
    condition connection control cook copper copy cord cork corn cough country cover
    cow crack cracker crate crayon cream creature credit crib crime crook crow crowd
    crown crush cry cub cup current curtain curve cushion dad daughter day death debt
    decision deer degree design desire desk detail development digestion dinner
    dinosaurs direction dirt discovery discussion disease distance division dock
    doctor dog doll donkey door downtown drain drawer dress drink drop drug drum duck
    dust ear earth earthquake edge education effect egg eggnog elbow end engine error
    event example exchange existence expansion experience expert eye face fact fall
    family fan farm farmer father faucet fear feast feather feeling feet fiction field
    fight finger fire fireman fish flag flame flavor flesh flight flock floor flower
    fly fog fold food foot force fork form fowl frame friction friend frog front
    fruit fuel furniture game garden gate ghost giraffe girl glass glove glue goat
    gold goldfish goose government governor grade grain grandfather grandmother grape
    grass grip ground group growth guide guitar gun hair hall hammer hand harbor hat
    head health heart heat help hen hill history hole holiday home honey hook hope
    horn horse hose hospital hour house humor hydrant ice idea impulse income
    increase industry ink insect instrument insurance interest invention iron island
    jail jam jar jeans jelly jewel joke journey judge juice jump kettle key kick kiss
    kite kitten knee knife knot knowledge lake lamp land language laugh lawyer lead
    leaf leather leg letter lettuce level library light limit line lip liquid list
    lizards lock look loss love lunch machine magic maid mailbox man manager map
    marble mark market mask mass match meal measure meat meeting memory men metal
    mice middle milk mind mine minister mint minute mist mitten mom money monkey
    month moon morning mother motion mountain mouth move muscle music nail name nation
    neck need needle nerve nest net news night noise north nose note notebook number
    nut oatmeal observation ocean offer office oil operation opinion orange order
    organization ornament oven owl owner page pail pain paint pan pancake paper
    parcel parent park part partner party passenger paste patch payment peace pear pen
    pencil person pet pickle picture pie pig pin pipe pizzas place plane plant
    plastic plate play playground pleasure plot plough pocket point poison police
    polish pollution popcorn position pot potato powder power price print prison
    process produce profit property prose protest pull pump punishment purpose push
    quarter queen question rabbit rail railway rain rake range rat rate ray reaction
    reading reason receipt record regret relation religion representative request
    respect rest reward rhythm rice riddle rifle ring river road rock rod roll roof
    room rose route rub rule run sack sail salt sand scale scarecrow scarf scene
    scent school science scissors screw sea seat secretary seed selection sense
    servant shade shake shame shape sheep sheet shelf ship shirt shock shoe shop show
    side sidewalk sign silk silver sink sister size skate skin skirt sky sleep sleet
    slip slope smash smell smile smoke snail snake sneeze snow soap society sock soda
    sofa son song sort sound soup space spade spark sponge spoon spot spring spy
    square squirrel stage stamp star start statement station steam steel stem step
    stew stick stitch stocking stomach stone stop store story stove stranger straw
    stream street stretch string structure substance sugar suggestion suit summer sun
    support surprise sweater swim swing system table tail talk tank taste tax teaching
    team teeth temper tendency tent territory test texture theory thing thought thread
    thrill throat throne thumb thunder ticket tiger time tin title toad toe tomatoes
    tongue tooth toothbrush top touch town toy trade trail train transport tray
    treatment tree trick trip trouble trousers truck tub turkey turn twig twist
    umbrella uncle underwear unit vacation value van vase vegetable veil vein verse
    vessel vest view visitor voice volcano volleyball voyage walk wall war wash waste
    watch water wave wax way wealth weather week weight wheel whip whistle wind window
    wine wing winter wire wish woman wood wool word work worm wound wren wrench wrist
    writer writing yak yam yard yarn year yoke zebra zinc zipper zoo
);

my @VERBS = qw(
    abides accepts achieves acts adds admires admits adopts advises agrees alerts
    allows amuses analyzes announces answers appears applauds appoints appreciates
    approves argues arranges arrives asks assembles assists assures attaches attacks
    attempts attends attracts avoids bakes balances bans bangs bathes battles beams
    bears beats becomes begs begins behaves belongs bends bets bites bleeds blesses
    blinks blows boasts boils bombs books bores borrows bounces bows brakes breaks
    breathes brings broadcasts brushes bubbles builds bumps burns bursts buys
    calculates calls camps cares carries carves catches causes challenges changes
    charges chases cheats checks cheers chews chokes chooses chops claims claps
    cleans clears clips closes collects colors combs comes commands communicates
    compares competes compiles complains completes composes computes concentrates
    concerns concludes conducts confesses confronts confuses connects considers
    constructs consults contains continues controls converts copies corrects costs
    coughs counts covers cracks crashes crawls creates creeps crosses crushes cries
    cures curls cuts cycles damages dances dares deals decays decides decorates
    defines delays delivers demands depends describes deserves designs destroys
    detects determines develops digs directs disappears discovers discusses dislikes
    displays distributes dives divides doubles doubts drags drains draws dreams
    dresses drinks drips drives drops drums dries earns eats educates eliminates
    employs encourages ends endures enforces engineers enhances enjoys enters
    entertains escapes establishes estimates evaluates examines exceeds excites
    exercises exhibits exists expands expects experiments explains explodes expresses
    extends extracts faces fades fails fastens fears feeds feels fights files fills
    finds fires fits fixes flaps flees flings floats floods flows follows forces
    forecasts forgets forgives forms frames freezes frightens gathers gazes generates
    gets gives glows goes governs grabs greets grins grinds grips groans grows guards
    guesses guides hammers handles hangs happens harms hates heads heals heaps hears
    heats helps hides hits holds hooks hops hopes hovers hugs hums hunts hurries
    hurts identifies ignores imagines implements impresses improves includes increases
    influences informs inspects inspires installs instructs interests introduces
    invents investigates invites irritates jails jams jogs joins jokes judges jumps
    justifies keeps kicks kills kisses kneels knits knocks knows labels lands lasts
    laughs launches leads leans leaps learns leaves lends lies lifts lights likes
    listens lives loads locates locks looks loses loves maintains makes manages maps
    marks marries matches matters measures meets melts memorizes mends mentions milks
    mines misleads misses mixes moans models modifies monitors motivates mourns moves
    murders nails names navigates needs negotiates nests nods notes notices numbers
    obeys objects observes obtains occurs offends offers opens operates orders
    organizes originates overcomes overflows owns packs paints parks participates
    passes pats pauses pays pecks peels performs permits persuades picks pilots places
    plans plants plays pleases plugs points pokes polishes possesses posts pours
    practices praises prays precedes predicts prefers prepares presents preserves
    prevents prints processes produces promises promotes proposes protects provides
    publishes pulls pumps punches purchases pushes questions queues races rains raises
    reaches reads realizes reasons receives recognizes recommends records reduces
    refers reflects refuses regrets relaxes releases relies remains remembers removes
    repairs repeats replaces replies reports represents requests rescues researches
    resolves responds restores retires retrieves returns reviews rides rings rises
    risks robs rocks rolls rots rubs ruins rules runs sails satisfies saves says
    scares scatters scolds scrapes screams scrubs seals searches selects sells sends
    separates serves settles shakes shapes shares shaves shelters shines shivers
    shocks shoots shops shows shuts sighs signs sings sips sits skips slaps sleeps
    slides slips slows smashes smells smiles smokes sneezes soaks solves sorts sounds
    speaks speeds spells spends spills spins splits spots sprays spreads springs
    squeezes stains stamps stands stares starts stays steals steers steps sticks
    stings stirs stops stores straps strengthens stretches strikes strips strokes
    studies stuffs subtracts succeeds suffers suggests suits summarizes supplies
    supports surprises surrounds suspects suspends swears sweeps swells swims swings
    takes talks tames taps tastes teaches tears teases tells tempts tests thanks
    thinks throws ties times tips tires touches tours traces trades trains transfers
    transforms transports traps travels treats trembles tricks trips troubles trusts
    tries tugs tumbles turns twists types understands unfastens unites unlocks
    unpacks updates upgrades upsets uses visits waits wakes walks wanders wants warms
    warns washes wastes watches waters waves wears weaves welcomes whispers whistles
    wins winks wipes wishes wonders works worries wraps wrecks wrestles writes yawns
    yells zooms
);

my @ADVERBS = qw(
    abnormally accidentally actually adventurously afterwards almost always angrily
    anxiously arrogantly awkwardly badly bashfully beautifully bitterly bleakly
    blindly blissfully boastfully boldly bravely briefly brightly briskly broadly
    busily calmly carefully carelessly cautiously certainly cheerfully clearly
    cleverly closely colorfully commonly continually coolly correctly courageously
    crossly cruelly curiously daily daintily dearly deceivingly deeply defiantly
    deliberately delightfully diligently dimly doubtfully dreamily easily elegantly
    energetically enormously enthusiastically equally especially evenly eventually
    exactly excitedly extremely fairly faithfully famously fast fatally ferociously
    fiercely fondly foolishly fortunately frankly frantically freely frightfully
    fully furiously generally generously gently gladly gleefully gracefully gratefully
    greatly greedily happily hastily healthily heavily helpfully helplessly highly
    honestly hopelessly hourly hungrily immediately innocently inquisitively instantly
    intensely intently interestingly inwardly irritably jealously joyfully joyously
    jovially jubilantly justly keenly kiddingly kindly knowingly knowledgeably lazily
    lightly likely limply lively loftily longingly loosely lovingly loudly loyally
    madly majestically meaningfully mechanically merrily miserably mockingly monthly
    mortally mostly mysteriously naturally nearly neatly nervously never nicely
    noisily obediently obnoxiously oddly offensively officially often only openly
    optimistically overconfidently painfully patiently perfectly physically playfully
    politely poorly positively potentially powerfully promptly properly punctually
    quaintly quickly quietly rapidly rarely readily really recklessly regularly
    reluctantly repeatedly reproachfully restfully righteously rigidly roughly rudely
    sadly safely scarcely scarily searchingly sedately seemingly seldom selfishly
    separately seriously shakily sharply sheepishly shrilly shyly silently sleepily
    slowly smoothly softly solemnly solidly sometimes soon speedily stealthily sternly
    strictly successfully suddenly surprisingly suspiciously sweetly swiftly tenderly
    tensely terribly thankfully thoroughly thoughtfully tightly too tremendously
    triumphantly truly truthfully ultimately unexpectedly unfortunately unnaturally
    unnecessarily utterly upwardly urgently usefully uselessly usually vaguely vainly
    valiantly vastly verbally very viciously victoriously violently vivaciously
    voluntarily warmly weakly wearily well wholly wildly willfully wisely woefully
    wonderfully worriedly wrongly zealously zestfully
);

my @ADJECTIVES = qw(
    abandoned abrupt absent absorbed absurd abundant abusive acceptable accessible
    accidental accurate acid acoustic adamant adorable adventurous aggressive
    agreeable alert alive alleged alluring aloof amazing ambiguous ambitious amused
    ancient angry animated annoying anxious apathetic aquatic aromatic arrogant
    ashamed aspiring astonishing attractive automatic available average awake aware
    awesome awful bad barbarous bashful beautiful befitting belligerent beneficial
    bent best bewildered big billowy bitter bizarre black blue blushing boiling bold
    boorish boring bouncy boundless brainy brave brawny breakable breezy brief bright
    broad broken brown bumpy busy cagey calm capable careful careless caring cautious
    ceaseless certain changeable charming cheap cheerful chemical chief childlike
    chilly chubby chunky clean clear clever cloudy clumsy coherent cold colorful
    colossal comfortable common complete complex concerned confused conscious cool
    cooperative coordinated courageous cowardly crazy creepy crooked crowded cruel
    cuddly cultured curious curly curved cute cynical damaged damaging damp dangerous
    dapper dark dashing dazzling dead deadpan deafening dear debonair decisive deep
    defeated defiant delicate delicious delightful demonic dependent depressed
    descriptive deserted detailed determined different difficult diligent dirty
    disastrous discreet disgusted distinct disturbed dizzy domineering doubtful drab
    dramatic dreary drunk dry dull dusty dynamic eager early earthy easy economic
    educated efficacious efficient elastic elated elderly electric elegant elite
    embarrassed eminent empty enchanted enchanting encouraging endurable energetic
    enormous entertaining enthusiastic envious equal erratic ethereal evanescent
    evasive even excellent excited exciting exclusive exotic expensive exuberant
    fabulous faded faint fair faithful false familiar famous fancy fantastic far
    fascinated fast faulty fearful fearless feeble female fertile festive few fierce
    filthy fine finicky first fixed flagrant flashy flat flawless flimsy flowery
    fluffy foamy foolish forgetful fortunate frail fragile frantic free freezing
    fresh fretful friendly frightened full functional funny furry furtive futuristic
    fuzzy gabby gamy gaudy general gentle giant giddy gifted gigantic glamorous
    gleaming glib glistening glorious glossy godly good goofy gorgeous graceful
    grandiose grateful gray greasy great greedy green grey grieving groovy grotesque
    grouchy grubby gruesome grumpy gullible gusty habitual hallowed handsome handy
    hapless happy hard harmonious harsh hateful healthy heartbreaking heavenly heavy
    helpful helpless hesitant hideous high hilarious hissing historical holistic
    hollow homeless homely honorable horrible hospitable hot huge hulking humdrum
    humorous hungry hurried hushed husky hypnotic hysterical icy idiotic ignorant ill
    illegal illustrious imaginary immense imminent impartial imperfect impolite
    important impossible incandescent incompetent incredible industrious inexpensive
    infamous innate innocent inquisitive insidious instinctive intelligent interesting
    internal invincible irate irritating itchy jaded jagged jazzy jealous jittery
    jobless jolly joyous judicious juicy jumbled jumpy juvenile keen kind kindhearted
    kindly knotty knowing knowledgeable known labored lackadaisical lacking lame
    lamentable languid large last late laughable lavish lazy lean learned left legal
    lethal level light lively limping literate little living lonely long longing loose
    lopsided loud loutish lovely loving low lowly lucky ludicrous lumpy lush luxuriant
    lyrical macabre macho maddening madly magenta magical magnificent majestic
    makeshift male malicious mammoth maniacal many marked massive married marvelous
    material mature mean measly meaty medical meek mellow melodic melted merciful mere
    messy mighty military milky mindless miniature minor misty mixed moaning modern
    moldy momentous motionless mountainous muddled mundane murky mushy mute
    mysterious naive narrow nasty natural naughty neat nebulous necessary needless
    neighborly nervous new nice nifty nimble noiseless noisy nonchalant nondescript
    normal nostalgic nosy noxious null numberless numerous nutritious nutty oafish
    obedient obese obnoxious obscene observant obsolete obtainable oceanic odd old
    omniscient one onerous open opposite optimal orange ordinary organic ossified
    outgoing outrageous outstanding oval overconfident overjoyed overrated overt
    painful pale paltry panicky panoramic parallel parched past pastoral pathetic
    peaceful penitent perfect periodic perpetual petite physical picayune pink piquant
    placid plain plastic plausible pleasant plucky pointless poised polite political
    poor possessive possible powerful precious present pretty previous prickly private
    probable productive profuse protective proud psychedelic psychotic public puffy
    pumped puny purple pushy puzzled puzzling quack quaint quarrelsome questionable
    quick quiet quirky quixotic quizzical rabid ragged rainy rambunctious rampant
    rapid rare raspy ratty ready real rebel receptive red redundant reflective regular
    relieved remarkable reminiscent repulsive resolute resonant responsible rhetorical
    rich right righteous rightful rigid ripe ritzy robust romantic roomy rotten rough
    round royal ruddy rude rural rustic ruthless sad safe salty same sassy satisfying
    savory scandalous scarce scared scary scattered scientific scintillating scrawny
    screeching second secret secretive sedate seemly selective selfish separate
    serious shaggy shaky shallow sharp shiny shivering shocking short shrill shut shy
    sick silent silky silly simple simplistic sincere skillful skinny sleepy slim
    slimy slippery sloppy slow small smart smelly smiling smoggy smooth sneaky
    snobbish soft soggy solid somber sophisticated sordid sore sour sparkling special
    spectacular spicy spiffy spiky spiritual spiteful splendid spooky spotless
    spotted spurious squalid square squealing squeamish stale standing statuesque
    steadfast steady steep stereotyped sticky stiff stimulating stingy stormy straight
    strange striped strong stupendous stupid sturdy subdued subsequent substantial
    successful succinct sudden sulky super superb superficial supreme swanky sweet
    sweltering swift synonymous taboo tacit tacky talented tall tame tan tangible
    tangy tart tasteful tasteless tasty tawdry tearful tedious temporary tender tense
    terrible terrific tested testy thankful therapeutic thick thin thinkable thirsty
    thoughtful thoughtless threatening thundering tidy tight tiny tired tiresome
    toothsome torpid tough towering tranquil trashy tremendous tricky trite troubled
    truculent true truthful typical ubiquitous ugly ultra unable unarmed unbiased
    uncovered understood undesirable unequal uneven unhealthy uninterested unique
    unkempt unknown unnatural unruly unsightly unsuitable untidy unusual unwieldy
    upbeat uppity upset uptight used useful useless utopian utter vacuous vague
    valuable various vast vengeful venomous verdant versed victorious vigorous violent
    violet vivacious voiceless volatile voracious vulgar wacky waggish waiting
    wakeful wandering wanting warlike warm wary wasteful watery weak wealthy weary
    wet whimsical whispering white whole wholesale wicked wide wiggly wild willing
    windy wiry wise wistful witty woebegone wonderful wooden woozy workable worried
    worthless wrathful wretched wrong wry yellow yielding young youthful yummy zany
    zealous zesty zippy zonked
);

my @PREPOSITIONS = qw(
    aboard about above across after against along alongside amid among around as at
    atop before behind below beneath beside between beyond by concerning considering
    despite down during except following for from in inside into like mid minus near
    next of off onto opposite outside over past per plus regarding round save since
    than through till to toward towards under underneath unlike until up upon versus
    via with within without
);

sub execute {
    my ($self, $ctx) = @_;

    my $adj  = $ADJECTIVES[ int(rand(scalar @ADJECTIVES)) ];
    my $noun = $NOUNS[ int(rand(scalar @NOUNS)) ];
    my $verb = $VERBS[ int(rand(scalar @VERBS)) ];
    my $adv  = $ADVERBS[ int(rand(scalar @ADVERBS)) ];
    my $prep = $PREPOSITIONS[ int(rand(scalar @PREPOSITIONS)) ];
    my $noun2 = $NOUNS[ int(rand(scalar @NOUNS)) ];

    $ctx->reply_public("The $adj $noun $verb $adv $prep the $noun2");
}

1;
