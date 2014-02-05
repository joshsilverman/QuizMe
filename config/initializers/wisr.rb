# @ugly, none of this should not be in an initializer

PROVIDERS = ["twitter"]

TWI_MAX_SCREEN_NAME_LENGTH = 15
TWI_SHORT_URL_LENGTH = 22 # variable occasionally increased by twitter: https://api.twitter.com/1/help/configuration.json

# @ugly, this should make use of Devise roles (wtf)
ADMINS = (Rails.env.test? ? [999999999999999999] : [1, 3, 4, 11])
WHITELISTED_MODERATORS = [
    11, # Josh Silverman
    6,  # DRathers - Jessi Royos
    5   # Charie Silades
  ]

AUTOFOLLOW_ASKER_IDS = [32588, 36605, 35106] # Neuro, AmericanRev, Respiratory

if Rails.env.production?
  URL = "http://wisr.com"
else
  URL = "http://localhost:3000"
end

TWI_DEV_SAFE_API_CALLS = [
  'mentions',
  'direct_messages',
  'retweets_of_me',
  'follower_ids',
  'user',
  'friendship?',
  'search'
]

LEARNER_LEVELS = [
  "unengaged", 
  "dm", 
  "share", 
  "mention", 
  "dm answer", 
  "twitter answer", 
  "feed answer",
  "author"
]

###Response Bank ###
CORRECT = [
  "That's right.",
  "Correct.",
  "Yes.",
  "That's it.",
  "You got it.",
  "Perfect.",
  "Perfecto.",
  "Nailed it.",
  "Right on.",
  "Exactly.",
  "Right.",
  "Affirmative.",
  "Yup!",
  "Yeah!" #,
  # "Totally.",
  # "Aye aye."
]
          
COMPLEMENT = [
  "Way to go!",
  "Keep it up!",
  "Nice job!",
  "Nice work!",
  "Booyah!",
  "Nice going!",
  "Hear that? That's the sound of AWESOME happening!",
  "Woot woot!",
  "Woooooot!",
  "Woohoo!!",
  "Nice!",
  # "Like a pro!",
  # "You should be teaching this stuff!",
  "Terrific!",
  "Excellent!",
  "Wonderful!",
  "Fantastic!",
  "Tremendous!",
  "Super!",
  # "Well look at you!",
  # "You must be practicing!",
  "Well done!",
  # "Good thinking!",
  # "You're really learning a lot!",
  "Good going!",
  "",
  "",
  "",
  "",
  "",
  "",
  "",
  ""
]

INCORRECT = [
  "Hmmm, not quite.",
  "Uh oh, that's not it...",
  "Sorry, that's not what we were looking for.",
  "Nope. Time to hit the books!",
  "Sorry. Close, but no cigar.",
  "Not quite.",
  "That's not it."
]

PROGRESS_COMPLEMENTS = [
  "Keep up the nice work!", 
  "Awesome work!",
  "Good going!",
  "Good stuff!",
  "Keep it up!",
  "Solid!",
  "Nice!"
]

FAST = [
  "Fast fingers! Faster brain!",      
  "Speed demon!",      
  "Woah! Greased lightning!",      
  "Too quick to handle!",      
  "Winning isn't everything. But it certainly is nice ;)",      
  "Fastest Finger Award Winner!",      
  "Hey, gunslinger! Fastest hands on the interwebs!"      
]

REENGAGE = [
  "Pop quiz:",
  "A question for you:",
  "Do you know the answer?",
  "Quick quiz:",
  "We've missed you!"
]

AGGREGATE_POST_RESPONSES = {
  :tons_correct => [
    "answered {num_correct} correctly... I don't think I can even count that high!"
  ],
  :many_correct => [
    "is on a roll! That's {num_correct} correct answers!",
    "is on a streak! That's {num_correct} correct answers!",
    "is in the zone! That's {num_correct} correct answers!",
    "is on fire! That's {num_correct} correct answers!",
    "is unstoppable! That's {num_correct} correct answers!"
  ],
  :multiple_correct => [
    "answered {num_correct} correctly. Boom!",
    "answered {num_correct} correctly. Booyah!"
  ],
  :multiple_answers => [
    "just answered {count} questions!"
  ],
  :one_answer => [
    "just answered a question... nice!",
    "just answered a question... sweet!",
    "answered a question... nice!",
    "answered a question... sweet!"    
  ]
}

SCRIPTS = {
  next_time: "You'll get it next time!",
  smile: ":)",
  awesome: "Awesome!",
  thanks: "Thank you",
  gotcha: "Gotcha",
  tweet_not_dm: "Can you hit reply directly to my question tweet next time? It's hard for me to link it if you DM the answer...",
  refer_friend: "Refer a friend?",
  reply_to_question: "Hmm, could you reply directly to the question you are answering?"
}

UGC_SCRIPTS = {
  submitted: "Thanks, just submitted your question and will post it soon!",
  provide_answers: "Great, could you provide me with the correct answer and a couple of good incorrects?",
  which_correct: "Thanks, and which is the correct answer?"
}

USER_TAG_SEARCH_TERMS = {
  teacher: ['teacher', 'teach', 'professor'],
  student: ['student']
}

SEGMENT_HIERARCHY = {
  1 => [7, 1, 2, 3, 4, 5, 6], #lifecycle segments
  2 => [7, 1, 2, 3, 4, 5, 6],
  3 => [],
  4 => [],
  5 => [1, 2, 3, 4, 5]
}

# UGC_REQUESTS = [
#   "You know this material pretty well, how about writing a question or two? Go here: {link}",
#   "You're pretty good at this stuff! Try writing a question or two for others to answer: {link}",
#   "Want to post your own question on {asker}? Write one here: {link}",
#   "Would you be interested in contributing some questions of your own? Do so here: {link}",
#   "Do you have any of your own questions for the community? Share them here: {link}"
# ]

INCLUDE_ANSWERS = [12982, 14106, 19454, 12640, 227, 9217]
# 227 - vocab
# 9217 - lsat

UNDER_CONSTRUCTION_HANDLES = []

ACCOUNT_DATA = {
  ## QuizMeBio
  18 => {
    :retweet => [19, 326, 14106, 26522, 32588, 32575, 26070, 28064], 
    :hashtags => ["science", "biology", "premed", "medschool"],
    :category => "Life Sciences",
    :search_terms => ['bio #nerd', 'biology #nerd', '#ilovebio', '#bionerd', '#apbio']
  }, 
  ## QuizMeChem
  19 => {
    :retweet => [18, 31, 326, 7362, 19454, 26522, 32588, 32575, 26070, 28064], 
    :hashtags => ["science", "chemistry"],
    :category => "Life Sciences",
    :search_terms => ['chem #nerd', 'chemistry #nerd', '#apchem']
  },  
  ## QuizMeOrgo
  31 => {
    :retweet => [18, 19, 108, 326, 14106, 26522, 32588, 32575, 26070, 28064], 
    :hashtags => ["science", "premed", "orgo"],
    :category => "Life Sciences",
    :search_terms => ['#orgo', '#organicchem', "'organic chem'", 'chem #nerd']
  }, 
  ## QuizMePsych
  108 => {
    :retweet => [18, 19, 31, 326, 191, 26522, 32588, 26070], 
    :hashtags => ["science", "psych"],
    :category => "Life Sciences",
    :search_terms => ['#psych101', '#psychology101', '#psychmajor', "'psych major'"]
  },  
  ## QuizMeAnat  
  326 => {
    :retweet => [18, 19, 31, 108, 14106, 26522, 32588, 26070], 
    :hashtags => ["science", "premed", "medschool", "anatomy", "trivia"],
    :category => "Life Sciences",
    :search_terms => ['#anatomy101', 'anatomy #nerd']
  },  
  ## Hematology_101
  28064 => {
    :retweet => [18, 19, 31, 108, 14106, 26522, 32588, 26070], 
    :hashtags => ["hematology"],
    :category => "Life Sciences",
    :search_terms => ['studying hematology', 'hematology exam']
  },

  ## QuizMeWeather
  7362 => {
    :retweet => [18, 19, 14106, 19454, 32575], 
    :hashtags => ["trivia", "weather", "meteorology", "meteo"],
    :category => "Trivia",
    :search_terms => ['weather geek', 'weather #nerd']
  },  
  ## QuizMeGeo
  8367 => {
    :retweet => [8373, 324],
    :hashtags => ["geo", "geography", "worldgeo"],
    :category => "Trivia",
    :search_terms => ["geography test", 'geography #nerd', 'maps #nerd']
  },  
  ## QuizMeVetMed
  26522 => {
    :retweet => [326, 31, 18, 19, 32588, 28064],
    :hashtags => ["vetmed", "veterinarian"],
    :category => "Misc",
    :search_terms => ['vetmed', "'vet school'", "'veterinary school'"]
  },
  ## QuizMeNeuro
  32588 => {
    :retweet => [18, 19, 31, 108, 14106, 26522, 326, 28064],
    :hashtags => ["neuro", "neuroscience", "brain"],
    :category => "Life Sciences",
    :search_terms => ["studying neuro exam", "neuro exam", 'neuroscience test']
  },
  ## PrepMeNREMT
  26070 => {
    :retweet => [18, 19, 31, 108, 14106, 26522, 326],
    :hashtags => ["emt", "NREMT"],
    :category => "Life Sciences",
    :search_terms => ["NREMT test", 'nremt']
  },
  #QuizMePhysics
  27857 => {
    :retweet => [26522, 8367, 7362, 326, 18, 19, 31, 108],
    :hashtags => ['physics'],
    :category => "Life Sciences",
    :search_terms => ['studying for physics', 'physics #nerd']
  },
  ## PhotosynthQuiz
  32575 => {
    :retweet => [18, 31, 19, 7362],
    :hashtags => ['biology', 'photosynthesis'],
    :category => "Life Sciences",
    :search_terms => ['studying photosynthesis', 'photosynthesis test'] 
  },
  ## ImmuneSystmQuiz
  35127 => {
    :hashtags => ['immune', 'immunology'],
    :search_terms => ['studying immunology', 'immune system test']
  },
  ## RespiratoryQuiz
  35106 => {
    :hashtags => ['respiratory', 'respiratorysystem'],
    :search_terms => ['studying respiratory', 'respiratory system', 'respiratory quiz', 'respiratory test']
  },
  ## QuizMeGenetics
  35213 => {
    :search_terms => ['genetics studying']
  },

  ## PrepMeMCATBio
  34530 => {
    :hashtags => ['mcat', 'biology'],
    :search_terms => ['mcat bio']
  },  
  ## PlantGrowthQuiz
  34905 => {
    :hashtags => ['botany', 'plants', 'plantgrowth'],
    :search_terms => ['studying botany', 'botany test']
  },
  ## StereochemQuiz
  35448 => {
    :hashtags => ['stereochem', 'stereochemistry'],
    :search_terms => ['stereochemistry']
  },
  ## PhysiologyQuiz
  35590 => {
    :hashtags => ['physio', 'physiology'],
    :search_terms => ['studying physiology', 'physiology study']
  },
  ## DermMyotomeQuiz
  34320 => {
    :search_terms => ['dermatome']
  },
  ## LogarithmsQuiz
  34963 => {
    :search_terms => ['logarithms test']
  },
  ## LowerLimbQuiz
  34662 => {
    :search_terms => ['lower limb']
  },


  ## SpanSubjunctive
  35459 => {
    :hashtags => ['spanish', 'espanol', 'subjunctive'],
    :search_terms => ['spanish subjunctive']
  },

  ## QuizMeFrenchRev
  35685 => {
    :hashtags => ['frenchrev', 'frenchrevolution', 'history'],
    :search_terms => ['studying french revolution', 'french revolution test']
  },
  ## AmericanRevQuiz
  36605 => {
    :hashtags => ['history', 'americanrevolution'],
    :search_terms => ['studying american revolution', 'american revolutionary war']
  },  

  ## SATvocabQuiz
  227 => {
    :retweet => [324, 308, 284], 
    :hashtags => ["trivia", "vocab", "wordnerd", "sat", "satprep", "testprep"],
    :category => "Trivia",
    :search_terms => ['#sat', '#highschool', 'psat', 'act']
  },  
  ## US Capitals 
  324 => {
    :retweet => [227, 308, 66, 2], 
    :hashtags => ["trivia"],
    :category => "Trivia",
    :search_terms => ["'US geography'", '#trivia']
  },
  ## QuizMeCapitals
  34534 => {
    :hashtags => ['trivia', 'geography'],
    :search_terms => ['capitals geography', 'world capitals test']
  },

  # ## Govt101
  # 2 => {
  #   :retweet => [], 
  #   :hashtags => ["election2012", "govt", "politics"]
  # }, 
  ## USPresidents101
  66 => {
    :retweet => [2, 191, 231, 322, 325, 324, 9217], 
    :hashtags => ["presidents", "history", "trivia"],
    :category => "Social Sciences",
    :search_terms => ["'US history'"]
  }, 
  ## PhilosophyQuiz
  191 => {
    :retweet => [2, 66, 231, 322, 325, 108, 9217, 32588, 32584], 
    :hashtags => ["philosophy", "philosopher"],
    :category => "Social Sciences",
    :search_terms => ['#philosophyclass', '#philosophy101', 'philosophy class', 'philosophy', 'plato', 'aristotle']
  }, 
  ## HistoryHabit
  231 => {
    :retweet => [2, 66, 191, 322, 325, 9217, 32584], 
    :hashtags => ["history", "trivia", "historybuff"],
    :category => "Social Sciences",
    :search_terms => ['#history101', '#historyclass', '#historybuff']
  }, 
  ## QuizMeEcon  
  322 => {
    :retweet => [2, 66, 191, 223, 231, 325, 9217], 
    :hashtags => ["econ", "economics"],
    :category => "Social Sciences",
    :search_terms => ['#econ101', '#economics101', '#econmajor', 'economics #nerd', 'econ #nerd']
  },
  ## AP US History 
  325 => {
    :retweet => [2, 66, 191, 231, 322, 374, 9217, 14106, 12640], 
    :hashtags => ["history", "trivia", "historybuff"],
    :category => "Social Sciences",
    :search_terms => ['#apus', '#apushistory', "'history buff'", "history #nerd"]
  },
  ## PrepMeLSAT
  9217 => {
    :retweet => [2, 66, 191, 231, 322, 325], 
    :hashtags => ["lsat", "lawschool", "law"],
    :category => "Social Sciences",
    :search_terms => ['lsat studying', 'lsat prep', '#lsat']
  },
  ## QuizMeArtHist
  32584 => {
    :retweet => [191, 231], 
    :hashtags => ["art", "artist", "arthistory"],
    :category => "Art",
    :search_terms => ['studying art history', 'art history nerd']
  },
  ## QuizMeConstLaw
  36144 => {
    :search_terms => ['study constitutional law']
  },

  ## Marketing_Quiz
  223 => {
    :retweet => [322], 
    :hashtags => ["marketing"],
    :category => "Misc",
    :search_terms => ['#marketing101', '#marketing', "'marketing class'"]
  },  
  ## QuizMeBeer  
  374 => {
    :retweet => [22, 284, 325], 
    :hashtags => ["trivia", "beer", "craftbeer", "brewing"],
    :category => "Misc",
    :search_terms => ['beer geek']
  },
  ## QuizMeThailand
  8373 => {
    :retweet => [8367, 324, 325],
    :hashtags => ["thailand", "thai", "thaiTrivia"],
    :category => "Misc",
    :search_terms => ['traveling thailand']
  },

  ## QuizMeCycling 
  22 => {
    :retweet => [284, 374], 
    :hashtags => ["trivia", "cycling", "bicycle"],
    :category => "Sports",
    :search_terms => ['#cycling']
  },
  ## QuizMeFootball  
  284 => {
    :retweet => [22, 374, 227], 
    :hashtags => ["trivia", "football", "nfl"],
    :category => "Sports",
    :search_terms => ["'football trivia'", '#sportstrivia', 'football']
  },

  #HarryPotterBk3
  10565 => {
    :retweet => [10567, 14106, 12640, 10572, 10573],
    :hashtags => ['potterhead', 'potter', 'harrypotter', 'PrisonerOfAzkaban'],
    :category => "Literature",
    :search_terms => ['#harrypotter', '#potter', '#potterhead', '#hogwarts', '#sortinghat']
  },
  #QuizHungerGames
  10567 => {
    :retweet => [10565, 10572,10573],
    :hashtags => ['hungergames', 'thehungergames', 'katniss'],
    :category => "Literature",
    :search_terms => ['#hungergames', '#maytheoddsbeeverinyourfavor', "'may the odds be ever in your favor'", 'katniss', 'the hunger games', 'peeta']
  },
  #Romeo and Juliet
  10566 => {
    :retweet => [],
    :hashtags => ['shakespeare', 'romeoandjuliet'],
    :category => "Literature",
    :search_terms => ['#shakespeare', '#romeoandjuliet', "'romeo and juliet'"]
  },  

  ## 501 Spanish 
  308 => {
    :retweet => [12982, 13588], 
    :hashtags => ["spanish", "espanol"],
    :category => "Language",
    :search_terms => ["'spanish class'", "#spanishclass"]
  },
  #Spanish_110
  12982 => {
    :retweet => [308, 13588],
    :hashtags => ['spanish', 'espanol', 'learnspanish'],
    :category => "Language",
    :search_terms => ['brush up spanish', 'brush up espanol']
  },
  #Beginner Spanish
  13588 => {
    :retweet => [308, 12982],
    :hashtags => ['spanish', 'espanol', 'learnspanish'],
    :category => "Language",
    :search_terms => ['espanol', 'learnspanish']
  },

  #SAThabit_algbra
  14106 => {
    :retweet => [12640, 19454, 24740],
    :hashtags => ['algebra', 'math', 'SAT', "SATprep"],
    :category => "Math",
    :search_terms => ['ilovealgebra', 'algebra #nerd', 'quadratic #nerd', 'math #nerd']
  },
  #SAThabit_numbrs
  19454 => {
    :retweet => [12640, 14106, 24740],
    :hashtags => ['algebra', 'math', 'SAT', "SATprep"],
    :category => "Math",
    :search_terms => ["'SAT studying'", '#ilovemath']
  },
  #SAThabit_math
  12640 => {
    :retweet => [14106, 19454, 24740],
    :hashtags => ['math', 'SAT', "SATprep"],
    :category => "Math",
    :search_terms => ['math #nerd']
  },
  #SAThabit_geomtr
  24740 => {
    :retweet => [14106, 19454, 12640],
    :hashtags => ['math', 'SAT', "SATprep, geometry"],
    :category => "Math",
    :search_terms => ['geometry #nerd']
  },
  #QuizMeCalculus
  # 22741 => {
  #   :retweet => [24740, 14106, 19454, 12640, 18, 19, 31],
  #   :hashtags => ['math', 'SAT', "SATprep, geometry"],
  #   :category => "Math"    
  # },

  #quimetwilight
  10572 => {
    :retweet => [10573,10565,10567],
    :hashtags => ['twilight', 'twilightsaga'],
    :category => "Literature",
    :search_terms => ['#twilight']
  },
  #quizmethehobbit
  10573 => {
    :retweet => [10572,10565,10567],
    :hashtags => ['thehobbit', 'lordoftherings', "jrrtolkien"],
    :category => "Literature",
    :search_terms => ['#hobbit']
  }
}