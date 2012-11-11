namespace :badges do

  task :load_questions => :environment do

    puts <<-EOS

      Which badge are you adding questions to (not case sensitive)?
    EOS
    input = STDIN.gets.chomp

    badge = Badge.where("title ILIKE ?", "%#{input}%").first
    unless badge.nil?
      puts <<-EOS

        Valid badge. What keywords do you want to use? (separate with ',')
      EOS
      input = STDIN.gets.chomp

      keywords = input.split ","
      questions = Question.where(:created_for_asker_id => badge.asker.id)
      where = []
      keywords.each do |keyword|
        where << "text ILIKE '%#{keyword.strip}%'"
      end
      questions = questions.where where.join " OR "

      if keywords.length >= 0
        puts <<-EOS

          Valid keywords. We found #{questions.length} questions.

        EOS

        questions.each_with_index do |question,i|
          puts <<-EOS
            #{i+1}. #{question.text}
          EOS
        end

        puts <<-EOS

          Rewrite questions? (y/n)
        EOS
        input = STDIN.gets.chomp

        if input == 'y'
          badge.questions = questions

          puts <<-EOS

            Complete. Exiting...
          EOS
        else
          puts <<-EOS

            OK. Aborting...
          EOS
        end
      else
        puts <<-EOS

          Not valid keywords.
        EOS
      end
    else
      puts <<-EOS

        Not a valid badge.
      EOS
    end
  end
end