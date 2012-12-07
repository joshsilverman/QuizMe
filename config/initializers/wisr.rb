# @ugly, none of this should not be in an initializer

PROVIDERS = ["twitter"]
## ADD studyeggtest back in (25)


# @ugly, this should make use of Devise roles (wtf)
ADMINS = [1, 3, 4, 11]

URL = (Rails.env.production? ? "http://wisr.com" : "http://wisr-stag.herokuapp.com")#"http://localhost:3000")

LEARNER_LEVELS = [
  "unengaged", 
  "dm", 
  "share", 
  "mention", 
  "dm answer", 
  "twitter answer", 
  "feed answer"
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
  "Yup.",
  "Yeah.",
  # "Totally.",
  "Aye aye."
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
  "Like a pro!",
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
  "Good thinking!",
  # "You're really learning a lot!",
  "Good going!",
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

ACCOUNT_DATA = {
  ## QuizMeBio
  18 => {
    :retweet => [19, 326, 14106], 
    :hashtags => ["science", "biology", "premed", "medschool"],
    :category => "Life Sciences"
  }, 
  ## QuizMeChem
  19 => {
    :retweet => [18, 31, 326, 7362, 14106], 
    :hashtags => ["science", "chemistry"],
    :category => "Life Sciences"
  },  
  ## QuizMeOrgo
  31 => {
    :retweet => [18, 19, 108, 326, 14106], 
    :hashtags => ["science", "premed", "orgo"],
    :category => "Life Sciences"
  }, 
  ## QuizMePsych
  108 => {
    :retweet => [18, 19, 31, 326, 191], 
    :hashtags => ["science", "psych"],
    :category => "Life Sciences"
  },  
  ## QuizMeAnat  
  326 => {
    :retweet => [18, 19, 31, 108, 14106], 
    :hashtags => ["science", "premed", "medschool", "anatomy", "trivia"],
    :category => "Life Sciences"
  },  
  ## QuizMeWeather
  7362 => {
    :retweet => [18, 19, 14106, 12640], 
    :hashtags => ["trivia", "weather", "meteorology", "meteo"],
    :category => "Life Sciences"
  },  
  ## QuizMeGeo
  8367 => {
    :retweet => [8373, 324],
    :hashtags => ["geo", "geography", "worldgeo"],
    :category => "Life Sciences"
  },  

  ## SATvocabQuiz
  227 => {
    :retweet => [324, 308, 284], 
    :hashtags => ["trivia", "vocab", "wordnerd", "sat", "satprep", "testprep"],
    :category => "Trivia"
  },  
  ## US Capitals 
  324 => {
    :retweet => [227, 308, 66, 2], 
    :hashtags => ["trivia"],
    :category => "Trivia"
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
    :category => "Social Sciences"
  }, 
  ## PhilosophyQuiz
  191 => {
    :retweet => [2, 66, 231, 322, 325, 108, 9217], 
    :hashtags => ["philosophy", "philosopher"],
    :category => "Social Sciences"
  }, 
  ## HistoryHabit
  231 => {
    :retweet => [2, 66, 191, 322, 325, 9217], 
    :hashtags => ["history", "trivia", "historybuff"],
    :category => "Social Sciences"
  }, 
  ## QuizMeEcon  
  322 => {
    :retweet => [2, 66, 191, 223, 231, 325, 9217], 
    :hashtags => ["econ", "economics"],
    :category => "Social Sciences"
  },
  ## AP US History 
  325 => {
    :retweet => [2, 66, 191, 231, 322, 374, 9217, 14106, 12640], 
    :hashtags => ["history", "trivia", "historybuff"],
    :category => "Social Sciences"
  },
  ## PrepMeLSAT
  9217 => {
    :retweet => [2, 66, 191, 231, 322, 325], 
    :hashtags => ["lsat", "lawschool", "law"],
    :category => "Social Sciences"
  },     

  ## Marketing_Quiz
  223 => {
    :retweet => [322], 
    :hashtags => ["marketing"],
    :category => "Misc"
  },  
  ## QuizMeBeer  
  374 => {
    :retweet => [22, 284, 325], 
    :hashtags => ["trivia", "beer", "craftbeer", "brewing"],
    :category => "Misc"
  },
  ## QuizMeThailand
  8373 => {
    :retweet => [8367, 324, 325],
    :hashtags => ["thailand", "thai", "thaiTrivia"],
    :category => "Misc"
  },

  ## QuizMeCycling 
  22 => {
    :retweet => [284, 374], 
    :hashtags => ["trivia", "cycling", "bicycle"],
    :category => "Sports"
  },
  ## QuizMeFootball  
  284 => {
    :retweet => [22, 374, 227], 
    :hashtags => ["trivia", "football", "nfl"],
    :category => "Sports"
  },

  #HarryPotterBk3
  10565 => {
    :retweet => [10567, 14106, 12640],
    :hashtags => ['potterhead', 'potter', 'harrypotter', 'PrisonerOfAzkaban'],
    :category => "Literature"
  },
  #QuizHungerGames
  10567 => {
    :retweet => [10565],
    :hashtags => ['hungergames', 'thehungergames', 'katniss'],
    :category => "Literature"
  },
  #Romeo and Juliet
  10566 => {
    :retweet => [],
    :hashtags => ['shakespeare', 'romeoandjuliet'],
    :category => "Literature"
  },  

  ## 501 Spanish 
  308 => {
    :retweet => [12982, 13588], 
    :hashtags => ["spanish", "espanol"],
    :category => "Language"
  },
  #Spanish_110
  12982 => {
    :retweet => [308, 13588],
    :hashtags => ['spanish', 'espanol', 'learnspanish'],
    :category => "Language"
  },
  #Beginner Spanish
  13588 => {
    :retweet => [308, 12982],
    :hashtags => ['spanish', 'espanol', 'learnspanish'],
    :category => "Language"    
  },
  #SAThabit_algbra
  14106 => {
    :retweet => [12640],
    :hashtags => ['algebra', 'math', 'SAT', "SATprep"],
    :category => "Math"
  },
  #SAThabit_math
  12640 => {
    :retweet => [14106],
    :hashtags => ['math', 'SAT', "SATprep"],
    :category => "Math"
  }
}