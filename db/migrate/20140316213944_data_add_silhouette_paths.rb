class DataAddSilhouettePaths < ActiveRecord::Migration
  def up
    # don't run data migration in test env
    return if Rails.env.test?

    askers_silhouettes_map = {
      "QuizMeThailand" => 'bg_images/tropics.svg', 
      "QuizMeChem" => 'bg_images/nature.svg', 
      "LogarithmsQuiz" => 'bg_images/nature.svg', 
      "prepmeLSAT" => 'bg_images/people.svg', 
      "USCapitals" => 'bg_images/city.svg', 
      "SAThabit_Numbrs" => 'bg_images/people.svg', 
      "PhilosophyQuiz" => 'bg_images/brains.svg', 
      "SAThabit_Algbra" => 'bg_images/city.svg', 
      "QuizMeOrgo" => 'bg_images/nature.svg', 
      "SATvocabQuiz" => 'bg_images/village.svg', 
      "LowerLimbQuiz" => 'bg_images/brains.svg', 
      "Spanish_110" => 'bg_images/village.svg', 
      "ImmuneSystmQuiz" => 'bg_images/brains.svg', 
      "StereochemQuiz" => 'bg_images/nature.svg', 
      "PrepMeMCATBio" => 'bg_images/tropics.svg', 
      "DermMyotomeQuiz" => 'bg_images/brains.svg', 
      "PrepMeNREMT" => 'bg_images/city.svg', 
      "AP_USHistory" => 'bg_images/ww2.svg', 
      "BegSpanish101" => 'bg_images/city.svg', 
      "sathabit_geomtr" => 'bg_images/city.svg', 
      "QuizMePhysics" => 'bg_images/mountains.svg', 
      "QuizMeVetMed" => 'bg_images/nature.svg', 
      "QuizMeWeather" => 'bg_images/tropics.svg', 
      "QuizMeGeo" => 'bg_images/city.svg', 
      "Hematology_101" => 'bg_images/brains.svg', 
      "CardiologyQuiz" => 'bg_images/brains.svg', 
      "QuizMeAnat" => 'bg_images/brains.svg', 
      "QuizMeArtHist" => 'bg_images/mountains.svg', 
      "QuizMeBeer" => 'bg_images/people.svg', 
      "SAThabit_Math" => 'bg_images/people.svg', 
      "QuizMeTheHobbit" => 'bg_images/village.svg', 
      "QuizMeBio" => 'bg_images/nature.svg', 
      "AmericanRevQuiz" => 'bg_images/village.svg', 
      "HarryPotterBk3" => 'bg_images/england.svg', 
      "QuizMeCapitals" => 'bg_images/city.svg', 
      "PlantGrowthQuiz" => 'bg_images/nature.svg', 
      "QuizMeTwilight" => 'bg_images/nature.svg', 
      "501SpanishVerbs" => 'bg_images/city.svg', 
      "QuizMeCycling" => 'bg_images/village.svg', 
      "PhotosynthQuiz" => 'bg_images/tropics.svg', 
      "Marketing_Quiz" => 'bg_images/city.svg', 
      "USPresidents101" => 'bg_images/people.svg', 
      "QuizMeEcon" => 'bg_images/city.svg', 
      "QuizMeFootball" => 'bg_images/england.svg', 
      "QuizMeWWII" => 'bg_images/ww2.svg', 
      "QuizMePsych" => 'bg_images/brains.svg', 
      "RespiratoryQuiz" => 'bg_images/brains.svg', 
      "QuizMeGenetics" => 'bg_images/brains.svg', 
      "HistoryHabit" => 'bg_images/ww2.svg', 
      "SpanSubjunctive" => 'bg_images/village.svg', 
      "QuizMeFrenchRev" => 'bg_images/village.svg', 
      "QuizHungerGames" => 'bg_images/village.svg', 
      "QuizMeConstLaw" => 'bg_images/city.svg'
    }

    askers_silhouettes_map.each do |twi_screen_name, path|
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
      styles['silhouette_image'] = path

      asker.update styles: {}
      asker.update styles: styles
    end
  end
end
