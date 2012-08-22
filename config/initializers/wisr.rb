PROVIDERS = ["twitter"]

if Rails.env == "development"
  URL = "http://studyegg-quizme-staging.herokuapp.com"
else
  URL = "http://www.wisr.com"
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