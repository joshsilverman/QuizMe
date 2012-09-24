PROVIDERS = ["twitter"]
ADMINS = [1, 3, 4, 11, 25]

if Rails.env.production?
  URL = "http://www.wisr.com"
else
  URL = "http://studyegg-quizme-staging.herokuapp.com"
end

###Response Bank ###
CORRECT =   ["That's right!",
          "Correct!",
          "Yes!",
          "That's it!",
          "You got it!",
          "Perfect!",
          ]
          
COMPLEMENT = ["Way to go",
            "Keep it up",
            "Nice job",
            "Nice work",
            "Booyah",
            "Nice going",
            "Hear that? That's the sound of AWESOME happening",
            ""]

INCORRECT =   ["Hmmm, not quite.",
            "Uh oh, that's not it...",
            "Sorry, that's not what we were looking for.",
            "Nope. Time to hit the books (or videos)!",
            "Sorry. Close, but no cigar.",
            "Not quite.",
            "That's not it."
            ]

FAST = ["Fast fingers! Faster brain!",
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
    :retweet => [66, 231, 191], 
    :hashtags => []
  }, 
  ## QuizMeBio
  18 => {
    :retweet => [19, 31, 108], 
    :hashtags => []
  }, 
  ## QuizMeChem
  19 => {
    :retweet => [18, 31, 108], 
    :hashtags => []
  },  
  ## QuizMeOrgo
  31 => {
    :retweet => [18, 19, 108], 
    :hashtags => []
  }, 
  ## USPresidents101
  66 => {
    :retweet => [2, 231, 191], 
    :hashtags => []
  }, 
  ## QuizMePsych
  108 => {
    :retweet => [18, 19, 31], 
    :hashtags => []
  },  
  ## PhilosophyQuiz
  191 => {
    :retweet => [2, 66, 231], 
    :hashtags => []
  }, 
  ## Marketing_Quiz
  223 => {
    :retweet => [], 
    :hashtags => []
  }, 
  ## SATvocabQuiz
  227 => {
    :retweet => [], 
    :hashtags => []
  },  
  ## HistoryHabit
  231 => {
    :retweet => [66, 191, 2], 
    :hashtags => []
  }, 

  ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }, 
  # ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # },  
  # ## Govt101
  # 2 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }, 
  # ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }, 
  # ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # },  
  # ## Govt101
  # 2 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }, 
  # ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }, 
  # ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # },  
  # ## Govt101
  # 2 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }, 
  # ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }, 
  # ## QuizMeBio
  # 18 => {
  #   :retweet => [], 
  #   :hashtags => []
  # }          
}

RETWEET_ACCTS = {
                  2 => [66], #govt101
                  19 => [31], #quizmechem
                  31 => [19], #quizmeorgo
                  66 => [2] #USPresidents101
                  #108 => [] #psychology 
                }