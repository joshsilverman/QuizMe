class DataAddQuestImageUrls < ActiveRecord::Migration
  def up
    # don't run data migration in test env
    return if Rails.env.test?

    askers_quest_map = {
      "QuizMeThailand" => 'quests/backpacker.png', 
      "QuizMeChem" => 'quests/scientist.png', 
      "LogarithmsQuiz" => 'quests/scholar.png', 
      "prepmeLSAT" => 'quests/scholar.png', 
      "USCapitals" => 'quests/president.png', 
      "SAThabit_Numbrs" => nil, 
      "PhilosophyQuiz" => nil, 
      "SAThabit_Algbra" => nil, 
      "QuizMeOrgo" => 'quests/scientist.png', 
      "SATvocabQuiz" => nil, 
      "LowerLimbQuiz" => 'quests/scientist.png', 
      "Spanish_110" => 'quests/spaniard.png', 
      "ImmuneSystmQuiz" => 'quests/scientist.png', 
      "StereochemQuiz" => 'quests/scientist.png', 
      "PrepMeMCATBio" => 'quests/naturalist.png', 
      "DermMyotomeQuiz" => 'quests/scientist.png', 
      "PrepMeNREMT" => 'quests/scientist.png', 
      "AP_USHistory" => 'quests/soldier.png', 
      "BegSpanish101" => 'quests/tourist.png', 
      "sathabit_geomtr" => 'quests/scholar.png', 
      "QuizMePhysics" => 'quests/scholar.png', 
      "QuizMeVetMed" => 'quests/scientist.png', 
      "QuizMeWeather" => 'quests/backpacker.png', 
      "QuizMeGeo" => 'quests/tourist.png', 
      "Hematology_101" => 'quests/doctor.png', 
      "CardiologyQuiz" => 'quests/scientist.png', 
      "QuizMeAnat" => 'quests/doctor.png', 
      "QuizMeArtHist" => 'quests/artist.png', 
      "QuizMeBeer" => nil, 
      "SAThabit_Math" => nil, 
      "QuizMeTheHobbit" => nil, 
      "QuizMeBio" => 'quests/naturalist.png', 
      "AmericanRevQuiz" => 'quests/revolutionary.png', 
      "HarryPotterBk3" => 'quests/harrypotter.png', 
      "QuizMeCapitals" => nil, 
      "PlantGrowthQuiz" => 'quests/naturalist.png', 
      "QuizMeTwilight" => 'quests/twilight.png', 
      "501SpanishVerbs" => 'quests/mexican.png', 
      "QuizMeCycling" => nil, 
      "PhotosynthQuiz" => 'quests/naturalist.png', 
      "Marketing_Quiz" => nil, 
      "USPresidents101" => 'quests/president.png', 
      "QuizMeEcon" => 'quests/scholar.png', 
      "QuizMeFootball" => 'quests/footballer.png', 
      "QuizMeWWII" => 'quests/soldier.png', 
      "QuizMePsych" => 'quests/psychoanalyst.png', 
      "RespiratoryQuiz" => 'quests/scientist.png', 
      "QuizMeGenetics" => 'quests/scientist.png', 
      "HistoryHabit" => 'quests/archeologist.png', 
      "SpanSubjunctive" => 'quests/spaniard.png', 
      "QuizMeFrenchRev" => 'quests/captain.png', 
      "QuizHungerGames" => nil, 
      "QuizMeConstLaw" => 'quests/scholar.png'
    }

    askers_quest_map.each do |twi_screen_name, path|
      asker = Asker.tfind twi_screen_name

      if !path
        puts "FAILED migration step: no path to set for asker"
        next
      end

      if !asker
        puts "FAILED migration step: no asker with specified twi screen name"
        next
      end

      if !File.exist?("app/assets/images/#{path}")
        puts "FAILED migration step: no file at that path"
      end

      styles = asker.styles || {}
      styles['quest_image'] = path

      asker.update styles: {}
      asker.update styles: styles
    end
  end
end
