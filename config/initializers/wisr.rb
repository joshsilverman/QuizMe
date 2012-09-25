PROVIDERS = ["twitter"]
ADMINS = [1, 3, 4, 11, 25]

URL = (Rails.env.production? ? "http://www.wisr.com" : "http://studyegg-quizme-staging.herokuapp.com")

###Response Bank ###
CORRECT = [
  "That's right!",
  "Correct!",
  "Yes!",
  "That's it!",
  "You got it!",
  "Perfect!"
]
          
COMPLEMENT = [
  "Way to go",
  "Keep it up",
  "Nice job",
  "Nice work",
  "Booyah",
  "Nice going",
  "Hear that? That's the sound of AWESOME happening",
  ""
]

INCORRECT = [
  "Hmmm, not quite.",
  "Uh oh, that's not it...",
  "Sorry, that's not what we were looking for.",
  "Nope. Time to hit the books (or videos)!",
  "Sorry. Close, but no cigar.",
  "Not quite.",
  "That's not it."
]

FAST = [
  "Fast fingers! Faster brain!",      
  "Speed demon!",      
  "Woah! Greased lightning!",      
  "Too quick to handle!",      
  "Winning isn't everything.  But it certainly is nice ;)",      
  "Fastest Finger Award Winner!",      
  "Hey, gunslinger! Fastest hands on the interwebs!"        
]

ACCOUNT_DATA = {
  ## Govt101
  2 => {
    :retweet => [66, 191, 231, 322, 325, 324], 
    :hashtags => []
  }, 
  ## USPresidents101
  66 => {
    :retweet => [2, 191, 231, 322, 325, 324], 
    :hashtags => []
  }, 
  ## PhilosophyQuiz
  191 => {
    :retweet => [2, 66, 231, 322, 325, 108], 
    :hashtags => []
  }, 
  ## HistoryHabit
  231 => {
    :retweet => [2, 66, 191, 322, 325], 
    :hashtags => []
  }, 
  ## QuizMeEcon  
  322 => {
    :retweet => [2, 66, 191, 223, 231, 325, 309, 310], 
    :hashtags => []
  },
  ## AP US History 
  325 => {
    :retweet => [2, 66, 191, 231, 322, 374], 
    :hashtags => []
  },    

  ## QuizMeBio
  18 => {
    :retweet => [19, 31, 108, 326], 
    :hashtags => []
  }, 
  ## QuizMeChem
  19 => {
    :retweet => [18, 31, 108, 326], 
    :hashtags => []
  },  
  ## QuizMeOrgo
  31 => {
    :retweet => [18, 19, 108, 326], 
    :hashtags => []
  }, 
  ## QuizMePsych
  108 => {
    :retweet => [18, 19, 31, 326, 191, 309, 310], 
    :hashtags => []
  },  
  ## QuizMeAnat  
  326 => {
    :retweet => [18, 19, 31, 108], 
    :hashtags => []
  },    

  ## Marketing_Quiz
  223 => {
    :retweet => [309, 310, 322], 
    :hashtags => []
  }, 
  ## Retail Management 
  309 => {
    :retweet => [223, 310, 108, 322], 
    :hashtags => []
  },  
  ## Consumer Behavior 
  310 => {
    :retweet => [223, 309, 108, 322], 
    :hashtags => []
  },  

  ## SATvocabQuiz
  227 => {
    :retweet => [324, 308, 284], 
    :hashtags => []
  },  
  ## 501 Spanish 
  308 => {
    :retweet => [227, 324], 
    :hashtags => []
  },
  ## US Capitals 
  324 => {
    :retweet => [227, 308, 66, 2], 
    :hashtags => []
  },

  ## QuizMeCycling 
  22 => {
    :retweet => [284, 374], 
    :hashtags => []
  },
  ## QuizMeFootball  
  284 => {
    :retweet => [22, 374, 227], 
    :hashtags => []
  },
  ## QuizMeBeer  
  374 => {
    :retweet => [22, 284, 325], 
    :hashtags => []
  }
}

# RETWEET_ACCTS = {
#   2 => [66], #govt101
#   19 => [31], #quizmechem
#   31 => [19], #quizmeorgo
#   66 => [2] #USPresidents101
#   #108 => [] #psychology 
# }